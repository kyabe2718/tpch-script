
DBCONFIG:=GEN_QUERY_PLAN=\\"EXPLAIN\\"\
    -DSTART_TRAN=\\"START\\ TRANSACTION\\"\
    -DEND_TRAN=\\"COMMIT\\"\
    -DSET_OUTPUT=\\"INTO\\ OUTFILE\\"\
    -DSET_ROWCOUNT=\\"LIMIT\\ %d\\\\n\\"\
    -DSET_DBASE=\\"USE\\ %s\\;\\\\n\\"

define LOAD_DATA
	@echo load data $(1) into $(2)...
	sed -e 's/|$$//' $(1) | psql -U postgres -d $(DBNAME) -c "copy $(2) from STDIN DELIMITER '|';"

endef

define EXEC_CMD
	psql -U postgres -d $(DBNAME) -c $(1)
endef

define EXEC_CMD_NO_DB
	psql -U postgres -c $(1)
endef

define EXEC_FILE
	psql -U postgres -d $(DBNAME) -f $(1)
endef

setup-db:
	@echo setup for postgres
