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

The service runs on loopback, with the socket in a private (0700) directory under
Homebrew's var rather than world-writable `/tmp`, and starts with
`--initialize-secure`:

```sh
brew services start tidb-server
mysql -S "$(brew --prefix)/var/tidb-run/tidb.sock" -uroot
```

A fresh datastore bootstraps `'root'@'localhost'` with the `auth_socket` plugin,
so root has no password and can only connect over that socket as the OS user that
started the server. There is no wildcard `root@'%'`, and the unauthenticated
status HTTP service (`/metrics`, `/settings`, `/debug/pprof`) is disabled.

An older datastore left at `$(brew --prefix)/var/tidb` is never opened: this
version uses its own `var/tidb-26` directory, so the old accounts are not
reachable. `brew install` warns when an old store is present, and
`brew info tidb-server` has the SQL for migrating it deliberately.

Give applications their own least-privileged account. Connect with
`mysql -S "$(brew --prefix)/var/tidb-run/tidb.sock" -uroot` and type the SQL at the
prompt, replacing the placeholder with a password you choose (never put it on a
command line, where `ps` can see it):

```sql
CREATE USER 'app'@'127.0.0.1' IDENTIFIED BY '<app-password>';
GRANT SELECT, INSERT, UPDATE, DELETE ON yourdb.* TO 'app'@'127.0.0.1';
```

Data lives in `$(brew --prefix)/var/tidb-26`; service output is recorded in
`$(brew --prefix)/var/log/tidb-server.log`. `brew services start` registers the
job at login; use `brew services run tidb-server` for a one-session start.

## tiup

The formula compiles `$(brew --prefix)/var/tiup` in as TiUP's home (created
0700, owned by the installing user) and installs the pinned, build-verified TUF
root at `var/tiup/bin/root.json`, so the trust anchor is never fetched over the
network. Setting `TIUP_HOME` overrides that and must provide its own anchor.
