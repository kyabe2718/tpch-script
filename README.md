# TPCH Script
* TPC-Hベンチマークを実行するためのスクリプト群
    * PostgresとMySQLで使える

## Requirements
* TPC-Hのベンチマークをダウンロードし、external/に展開しておく
    * http://www.tpc.org/tpch/

* Postgres/MySQLのインストール
     * PostgresはpostgresユーザーでMySQLはrootユーザーがデフォルト

## Setup
```
$ make setup-all DBTYPE=${DBTYPE}
```
* `${DBTYPE}`にはpostgresかmysqlを入れる
    * 何も設定しなければpostgres

## Run
``
$ make run Q=${query number} DBTYPE=${DBTYPE}
```
* query numberは1~22の整数

``
$ make exp Q=${query number} DBTYPE=${DBTYPE}
```
* 実行計画も表示できる

## Note
* MySQLのInnoDBのバッファサイズなどをsrc/mysql.mk内で設定している
    * 値は適当
