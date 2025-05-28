# pg_collectors

Scripts and tools to collect PG data

## logs_collector.sh

Shell script to gather postgresql logs. You have to execute the command as root on the server that runs pg.

``` shell
./logs_collector.sh <detination_file>
```

## pg_gather

Sql to generate data needed by pg_gather.

Download [here](https://github.com/jobinau/pg_gather/blob/main/gather.sql).

``` shell
psql <connection_parameters_if_any> -X -f gather.sql | gzip > out.tsv.gz
```

More information here: [Github jobinau](https://github.com/jobinau/pg_gather)
pg_gather written by Jobin Augustine.

## Consulting scripts


Scripts used by Percona to collect pg data.

[pcs-collect-environment-pgsql.sh](https://percona.github.io/percona-consulting-scripts/src/pcs-collect-environment-pgsql.sh)

More information here.

[Percona Consulting Scripts](https://percona.github.io/percona-consulting-scripts/)
