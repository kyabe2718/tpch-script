# -----------------------------------------------------------------------------------------------------
#    Config
# -----------------------------------------------------------------------------------------------------

DBNAME:=tpcd
SF:=1
DBTYPE:=postgres
# DBTYPE:=mysql

# -----------------------------------------------------------------------------------------------------
#    Preliminaries
# -----------------------------------------------------------------------------------------------------

MAKEFILE_PATH:=$(realpath $(firstword $(MAKEFILE_LIST)))
MAKEFILE_DIR:=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))
DBGEN_DIR:=$(realpath $(shell find $(MAKEFILE_DIR)/external -type d -name dbgen))
BUILD_DIR:=$(MAKEFILE_DIR)build-$(DBTYPE)

ifeq "$(DBTYPE)" "postgres"
include $(MAKEFILE_DIR)/src/postgres.mk
else ifeq "$(DBTYPE)" "mysql"
include $(MAKEFILE_DIR)/src/mysql.mk
endif

$(BUILD_DIR)/tools.makefile: $(MAKEFILE_PATH)
	mkdir -p $(BUILD_DIR)
	cp -f $(DBGEN_DIR)/makefile.suite $(BUILD_DIR)/tools.makefile
	sed -i 's/^.*CC\s*=.*/CC =gcc/g' $(BUILD_DIR)/tools.makefile              # CC = gcc
	sed -i 's/DATABASE\s*=.*/DATABASE =$(DBCONFIG)/g' $(BUILD_DIR)/tools.makefile  # CUSTOM DATABASE CONFIG
	sed -i 's/MACHINE\s*=.*/MACHINE =LINUX/g' $(BUILD_DIR)/tools.makefile     # MACHINE = LINUX
	sed -i 's/WORKLOAD\s*=.*/WORKLOAD =TPCH/g' $(BUILD_DIR)/tools.makefile    # WORKLOAD = TPCH
	diff $(DBGEN_DIR)/makefile.suite $(BUILD_DIR)/tools.makefile || true      # print diff

.PHONY: tools
tools: $(BUILD_DIR)/tools.makefile
	$(MAKE) -C $(DBGEN_DIR) -f $(BUILD_DIR)/tools.makefile clean
	$(MAKE) -C $(DBGEN_DIR) -f $(BUILD_DIR)/tools.makefile
	cp $(DBGEN_DIR)/dbgen $(BUILD_DIR)
	cp $(DBGEN_DIR)/qgen $(BUILD_DIR)
	cat $(DBGEN_DIR)/dss.ddl | tr A-Z a-z > $(BUILD_DIR)/dss.ddl
	cp $(MAKEFILE_DIR)/src/dss.ri  $(BUILD_DIR)
	sed -i 's/CONNECT TO.*//g' $(BUILD_DIR)/dss.ri
	sed -i 's/COMMIT WORK.*//g' $(BUILD_DIR)/dss.ri
	sed -i -e 's/TPCD\.\([A-Z]*\)/\L\1/g' $(BUILD_DIR)/dss.ri
	sed -i 's/ADD FOREIGN KEY [_a-zA-Z0-9]* (\([,_a-zA-Z0-9]*\))/ADD FOREIGN KEY (\1)/g' $(BUILD_DIR)/dss.ri

.PHONY: gen-tbl
gen-tbl: tools
	@echo "Generating tables..."
	mkdir -p $(BUILD_DIR)/tbl
	cd $(BUILD_DIR)/tbl && $(BUILD_DIR)/dbgen -b $(DBGEN_DIR)/dists.dss -vf -s $(SF)

define GEN_QUERY
	@echo generate $(2).sql from $(1)
	cp $(1) $(BUILD_DIR)/tmp/$(2).sql
	sed -i 's/day ([0-9]*)/day/g' $(BUILD_DIR)/tmp/$(2).sql
	sed -i 's/:n -1//g' $(BUILD_DIR)/tmp/$(2).sql
	cd $(DBGEN_DIR) && DSS_QUERY=$(BUILD_DIR)/tmp ./qgen -b $(DBGEN_DIR)/dists.dss -s $(SF) -d $(2) > $(BUILD_DIR)/sql/$(2).sql
	sed -i 's/\r//g' $(BUILD_DIR)/sql/$(2).sql
	sed -i -z 's/;\n\(LIMIT.*$$\)/\n\1;/g' $(BUILD_DIR)/sql/$(2).sql

endef

.PHONY: gen-query
gen-query: tools $(wildcard $(DBGEN_DIR)/queries/*.sql)
	mkdir -p $(BUILD_DIR)/tmp
	mkdir -p $(BUILD_DIR)/sql
	$(foreach q, $(wildcard $(DBGEN_DIR)/queries/*.sql), $(call GEN_QUERY,$(q),$(basename $(notdir $(q)))))
	rm -rf $(BUILD_DIR)/tmp

.PHONY: load-data
load-data: gen-tbl $(wildcard $(BUILD_DIR)/tbl/*.tbl)
	$(MAKE) setup-db
	$(call EXEC_CMD_NO_DB,"drop database if exists $(DBNAME);")
	$(call EXEC_CMD_NO_DB,"create database $(DBNAME);")
	$(call EXEC_FILE,$(BUILD_DIR)/dss.ddl)
	$(foreach tblfile, $(wildcard $(BUILD_DIR)/tbl/*.tbl), $(call LOAD_DATA,$(tblfile),$(basename $(notdir $(tblfile)))))
	$(call EXEC_FILE,$(BUILD_DIR)/dss.ri)

.PHONY: setup-all
setup-all: gen-query load-data

Q=1
run:
	$(call EXEC_FILE,$(BUILD_DIR)/sql/$(Q).sql)

exp:
	$(call EXEC_FILE,$(BUILD_DIR)/sql/$(Q).sql.exp)

