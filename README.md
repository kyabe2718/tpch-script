# TPCH Script

## Requirements

* MySQL (>= 8.0?)

## create tables and generate queries

```
$ make setup-all SCALE_FACTOR=$(SF) TPCH_ZIP=/path/to/tpch-zip/ PASSWORD="password for root"
```

## exec queries

```
$ make all-test
```
