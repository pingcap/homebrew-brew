# homebrew-brew

Homebrew formulae for TiDB.

## Install

```sh
brew tap pingcap/brew
brew install tidb-server
brew install tiup
```

## tidb-server

TiDB v26.3.21, single node on the built-in `unistore` engine (no TiKV or PD
required).

The service is pinned to loopback and started with `--initialize-secure`:

```sh
brew services start tidb-server
mysql -S /tmp/tidb-4000.sock -uroot
```

A fresh datastore bootstraps `'root'@'localhost'` with the `auth_socket` plugin,
so root has no password and can only connect over the Unix socket as the OS user
that started the server. There is no wildcard `root@'%'`, and the
unauthenticated status HTTP service (`/metrics`, `/settings`, `/debug/pprof`) is
disabled.

Give applications their own least-privileged account:

```sql
CREATE USER 'app'@'127.0.0.1' IDENTIFIED BY 'choose-a-strong-password';
GRANT SELECT, INSERT, UPDATE, DELETE ON yourdb.* TO 'app'@'127.0.0.1';
```

Data lives in `$(brew --prefix)/var/tidb`. `brew services start` registers the
job at login; use `brew services run tidb-server` for a one-session start.
Upgrading from an older formula does not re-bootstrap an existing datastore —
see `brew info tidb-server` for the SQL that removes an old wildcard root.

## tiup

`brew info tiup` prints the one-time step that installs the pinned,
SHA-256-verified TUF root manifest into `~/.tiup/bin`.
