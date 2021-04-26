#! /bin/bash

if [[ -z "${SCALE_FACTOR}" ]]; then
    echo "SCALE_FACTOR isn't defined"
    exit 1
fi

if [[ -z "${DBGEN_DIR}" ]]; then
    echo "DBGEN_DIR isn't defined"
    exit 1
fi

if [[ -z "${BUILD_DIR}" ]]; then
    echo "BUILD_DIR isn't defined"
    exit 1
fi

echo SCALE_FACTOR: $SCALE_FACTOR
echo DBGEN_DIR: $DBGEN_DIR

mkdir -p ${BUILD_DIR}/{sql,explain-sql}


cd $DBGEN_DIR
export DSS_QUERY=${BUILD_DIR}/tmp

mkdir -p ${DSS_QUERY}

for f in $(find ${DBGEN_DIR}/queries -name *.sql); do
    f=$(basename $f)
    cp ${DBGEN_DIR}/queries/$f ${DSS_QUERY}/$f
    sed -i 's/day ([0-9]*)/day/g' ${DSS_QUERY}/$f
    sed -i 's/:n -1//g' ${DSS_QUERY}/$f
done

for i in $(seq 1 22); do
    ./qgen -b${DBGEN_DIR}/dists.dss -s ${SCALE_FACTOR} ${i} | sed 's/\r//g' | sed -z 's/;\n\(LIMIT.*$\)/ \1;/g' > ${BUILD_DIR}/sql/${i}.sql
    sed -z -i -e 's/create view \([^ ]*\)/drop view if exists \1;\n\ncreate view \1/g' ${BUILD_DIR}/sql/${i}.sql
    cat ${BUILD_DIR}/sql/${i}.sql | sed 's/^select/explain select/g' > ${BUILD_DIR}/sql/${i}.sql.exp
    echo "generate ${BUILD_DIR}/sql/${i}.sql"
done

rm -rf ${DSS_QUERY}

