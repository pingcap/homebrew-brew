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

The service runs on loopback, with the socket under Homebrew's var directory
rather than world-writable `/tmp`, and starts with `--initialize-secure`:

```sh
brew services start tidb-server
mysql -S "$(brew --prefix)/var/tidb.sock" -uroot
```

A fresh datastore bootstraps `'root'@'localhost'` with the `auth_socket` plugin,
so root has no password and can only connect over that socket as the OS user that
started the server. There is no wildcard `root@'%'`, and the unauthenticated
status HTTP service (`/metrics`, `/settings`, `/debug/pprof`) is disabled.

An existing datastore is not re-bootstrapped; `brew install` warns when one is
present, and `brew info tidb-server` has the SQL that removes an old wildcard
root.

Give applications their own least-privileged account:

```sql
CREATE USER 'app'@'127.0.0.1' IDENTIFIED BY 'choose-a-strong-password';
GRANT SELECT, INSERT, UPDATE, DELETE ON yourdb.* TO 'app'@'127.0.0.1';
```

Data lives in `$(brew --prefix)/var/tidb`; service output is recorded in
`$(brew --prefix)/var/log/tidb-server.log`. `brew services start` registers the
job at login; use `brew services run tidb-server` for a one-session start.

## tiup

`brew info tiup` prints the one-time step that installs the pinned,
SHA-256-verified TUF root manifest into `~/.tiup/bin`.
