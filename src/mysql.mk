
MEM_TOTAL:=$(shell free -b | grep Mem | awk '{print $$2}')

DBCONFIG:=GEN_QUERY_PLAN=\\"EXPLAIN\\"\
    -DSTART_TRAN=\\"START\\ TRANSACTION\\"\
    -DEND_TRAN=\\"COMMIT\\"\
    -DSET_OUTPUT=\\"INTO\\ OUTFILE\\"\
    -DSET_ROWCOUNT=\\"LIMIT\\ %d\\\\n\\"\
    -DSET_DBASE=\\"USE\\ %s\\;\\\\n\\"

define LOAD_DATA
	@echo load data $(1) into $(2)...
	mysql -u root --local-infile=1 -D $(DBNAME) -e \
		"load data local infile '$(1)' into table $(2) fields terminated by '|' lines terminated by '\n';"

endef

define EXEC_CMD
	mysql -u root -D $(DBNAME) -e $(1)
endef

define EXEC_CMD_NO_DB
	mysql -u root -e $(1)
endef

define EXEC_FILE
	cat $(1) | mysql -u root -D $(DBNAME)
endef

setup-db:
	@echo setup for mysql
	$(call EXEC_CMD_NO_DB, "SET GLOBAL local_infile=1;")
	$(call EXEC_CMD_NO_DB, "SET GLOBAL key_buffer_size=$(shell awk "BEGIN { print int($(MEM_TOTAL) / 4) }");")
	$(call EXEC_CMD_NO_DB, "SET GLOBAL innodb_buffer_pool_size=$(shell awk "BEGIN { print int($(MEM_TOTAL) / 2) }");")
