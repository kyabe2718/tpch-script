# -----------------------------------------------------------------------------------------------------
#    Config
# -----------------------------------------------------------------------------------------------------

SF:=10
DBNAME:=tpch_sf$(SF)
DBTYPE:=postgres
# DBTYPE:=mysql

# -----------------------------------------------------------------------------------------------------
#    Preliminaries
# -----------------------------------------------------------------------------------------------------

MAKEFILE_PATH:=$(realpath $(firstword $(MAKEFILE_LIST)))
MAKEFILE_DIR:=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))
DBGEN_DIR:=$(realpath $(shell find $(MAKEFILE_DIR)/external -type d -name dbgen))
BUILD_DIR:=$(MAKEFILE_DIR)build-$(DBNAME)

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
	cp        $(1)                         $(BUILD_DIR)/tmp/$(2).sql
	sed -i    's/day ([0-9]*)/day/g'       $(BUILD_DIR)/tmp/$(2).sql
	sed -i    's/:n -1//g'                 $(BUILD_DIR)/tmp/$(2).sql
	cd $(DBGEN_DIR) && DSS_QUERY=$(BUILD_DIR)/tmp ./qgen -b $(DBGEN_DIR)/dists.dss -s $(SF) -d $(2) > $(BUILD_DIR)/sql/$(2).sql
	sed -i -e '1i \timing'                 $(BUILD_DIR)/sql/$(2).sql
	sed -i    's/\r//g'                    $(BUILD_DIR)/sql/$(2).sql
	sed -i -z 's/;\n\(LIMIT.*$$\)/\n\1;/g' $(BUILD_DIR)/sql/$(2).sql
	sed       's/^select/explain select/i' $(BUILD_DIR)/sql/$(2).sql > $(BUILD_DIR)/sql/$(2).sql.exp
	sed       's/^select/explain (analyze) select/i' $(BUILD_DIR)/sql/$(2).sql > $(BUILD_DIR)/sql/$(2).sql.analyze
	sed       's/^select/explain (format json, analyze) select/i' $(BUILD_DIR)/sql/$(2).sql > $(BUILD_DIR)/sql/$(2).sql.analyze_json

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

.PHONY:exp
exp:
	$(call EXEC_FILE,$(BUILD_DIR)/sql/$(Q).sql.exp)

.PHONY:analyze
analyze:
	$(call EXEC_FILE,$(BUILD_DIR)/sql/$(Q).sql.analyze)

COMMA := ,
.PHONY: show
show:
	$(call EXEC_CMD,"SELECT tablename $(COMMA) indexname FROM pg_indexes WHERE tablename NOT LIKE 'pg_%';")
	$(call EXEC_FILE,src/pg_analyze.sql)


TMP_FILE:=/mnt/disk/tmpfile # to flush filesystem buffer
TMP_FILE_SIZE:=5000 #KB

$(TMP_FILE):
	dd if=/dev/random of=$(TMP_FILE) bs=1024k count=$(TMP_FILE_SIZE)

.PHONY: clear_cache
clear_cache:$(TMP_FILE)
	# sudo -u postgres /opt/postgres/bin/pg_ctl -D /mnt/disk/postgres/data -l /mnt/disk/postgres/logfile stop
	sync; echo 3 > sudo /proc/sys/vm/drop_caches
	sudo hdparm -f /dev/sda
	sudo hdparm -f /dev/sdb
	time wc -l $(TMP_FILE)
	sudo -u postgres /opt/postgres/bin/pg_ctl -D /mnt/disk/postgres/data -l /mnt/disk/postgres/logfile restart

