#! /bin/bash

if [[ -z "${BUILD_DIR}" ]]; then
    echo "BUILD_DIR isn't defined"
    exit 1
fi

if [[ -z "${DBNAME}" ]]; then
    echo "DBNAME isn't defined"
    exit 1
fi

if [[ -z "${PASSWORD}" ]]; then
    echo "PASSWORD isn't defined"
    exit 1
fi

echo BUILD_DIR: ${BUILD_DIR}
export MYSQL_PWD=${PASSWORD}

echo ""
echo drop database: ${DBNAME}
mysql -u root -e "drop database if exists ${DBNAME};"

# データベースが存在しなければ作る
echo "create database: ${DBNAME}"
mysql -u root -e "create database if not exists ${DBNAME};"

echo ""

# スキームの定義
echo "define schema: ${BUILD_DIR}/dss.ddl"
mysql -u root -D ${DBNAME} < ${BUILD_DIR}/dss.ddl
echo ""

mysql -u root -e "set global local_infile=1;"
for tblfile in $(find ${BUILD_DIR}/tbl -name *.tbl); do
    tblname=$(basename ${tblfile} ".tbl")
    echo load data $tblfile into ${DBNAME}.$tblname ...
    mysql -u root --local-infile=1 -D ${DBNAME} -e \
        "load data local infile '$tblfile' into table $tblname fields terminated by '|' lines terminated by '\n';"
done

echo ""

# cat ${BUILD_DIR}/dss.ri | sed 's/--.*$//g' | awk 'BEGIN{RS=";"}/ALTER TABLE sf1\.lineitem\nADD PRIMARY KEY/{print $7}'
echo "create index..."
time mysql -u root -D ${DBNAME} < ${BUILD_DIR}/dss.ri
