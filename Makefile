
MAKEFILE_PATH:=$(realpath $(firstword $(MAKEFILE_LIST)))
MAKEFILE_DIR:=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))

TPCH_ZIP:=tpc-h-tool.zip
TPCH_TOOL_DIR:=$(MAKEFILE_DIR)tpc-h-tool

PASSWORD:=$(shell cat $(MAKEFILE_DIR)password.txt)

SCALE_FACTOR:=1
DBNAME:=sf$(SCALE_FACTOR)
DBCONFIG:=GEN_QUERY_PLAN=\\"EXPLAIN\\"\
    -DSTART_TRAN=\\"START\\ TRANSACTION\\"\
    -DEND_TRAN=\\"COMMIT\\"\
    -DSET_OUTPUT=\\"INTO\\ OUTFILE\\"\
    -DSET_ROWCOUNT=\\"LIMIT\\ %d\\\\n\\"\
    -DSET_DBASE=\\"USE\\ %s\\;\\\\n\\"
BUILD_DIR:=$(MAKEFILE_DIR)/build/$(DBNAME)

.PHONY: extract-zip
extract-zip:
	unzip -uqq $(TPCH_ZIP) -d $(TPCH_TOOL_DIR)
	$(eval DBGEN_DIR:=$(shell find $(TPCH_TOOL_DIR) -type d -name dbgen))
	@echo "DBGEN_DIR:=$(DBGEN_DIR)"

# dbgen/makefile.suiteを元にMakefileを作製
$(DBGEN_DIR)/Makefile: $(MAKEFILE_PATH) extract-zip
	cp -f $(DBGEN_DIR)/makefile.suite $(DBGEN_DIR)/Makefile
	sed -i 's/^.*CC\s*=.*/CC =gcc/g' $(DBGEN_DIR)/Makefile
	sed -i 's/DATABASE\s*=.*/DATABASE =$(DBCONFIG)/g' $(DBGEN_DIR)/Makefile
	sed -i 's/MACHINE\s*=.*/MACHINE =LINUX/g' $(DBGEN_DIR)/Makefile
	sed -i 's/WORKLOAD\s*=.*/WORKLOAD =TPCH/g' $(DBGEN_DIR)/Makefile
	#diff $(DBGEN_DIR)/makefile.suite $(DBGEN_DIR)/Makefile || true

# 作製したMakefileによりdbgenとqgenをmake
.PHONY: dbgen-tools
dbgen-tools: $(DBGEN_DIR)/Makefile
	#$(MAKE) -C $(DBGEN_DIR) clean
	$(MAKE) -C $(DBGEN_DIR)
	mkdir -p $(BUILD_DIR)
	cp $(DBGEN_DIR)/dbgen $(BUILD_DIR)
	cp $(DBGEN_DIR)/qgen $(BUILD_DIR)
	cat $(DBGEN_DIR)/dss.ddl | tr A-Z a-z > $(BUILD_DIR)/dss.ddl
	#sed -e 's/TPCD\.\([A-Z]*\)/$(DBNAME).\L\1/g' $(DBGEN_DIR)/dss.ri > $(BUILD_DIR)/dss.ri
	sed -e 's/TPCD\.\([A-Z]*\)/$(DBNAME).\L\1/g' $(MAKEFILE_DIR)/script/dss.ri > $(BUILD_DIR)/dss.ri
	sed -i 's/TPCD/$(DBNAME)/g' $(BUILD_DIR)/dss.ri

.PHONY: gen-tbl
gen-tbl: dbgen-tools
	@echo "Generating tables..."
	mkdir -p $(BUILD_DIR)/tbl
	$(BUILD_DIR)/dbgen -b $(DBGEN_DIR)/dists.dss -vf -s $(SCALE_FACTOR)
	mv *.tbl $(BUILD_DIR)/tbl

.PHONY: setup-mysql
setup-mysql: gen-tbl
	BUILD_DIR=$(BUILD_DIR) PASSWORD=$(PASSWORD) DBNAME=$(DBNAME) $(MAKEFILE_DIR)/script/setup-mysql.sh

.PHONY: gen-query
gen-query: dbgen-tools
	@echo "Generating queries..."
	BUILD_DIR=$(BUILD_DIR) SCALE_FACTOR=$(SCALE_FACTOR) DBGEN_DIR=$(DBGEN_DIR) $(MAKEFILE_DIR)/script/gen-query.sh

.PHONY: setup-all
setup-all: setup-mysql gen-query

.PHONY: login-mysql
login-mysql:
	mysql -u root -p${PASSWORD}

TARGET=
.PHONY: test
test:
	DBNAME=$(DBNAME) PASSWORD=${PASSWORD} $(MAKEFILE_DIR)/script/exec-query.sh $(TARGET)

.PHONY: all-test
all-test:
	DBNAME=$(DBNAME) PASSWORD=${PASSWORD} $(MAKEFILE_DIR)/script/exec-query.sh $(shell find $(BUILD_DIR)/sql -name *.sql)

