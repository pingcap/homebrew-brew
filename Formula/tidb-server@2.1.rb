class TidbServerAT21 < Formula
  desc "TiDB is a MySQL compatible distributed database"
  homepage "https://www.pingcap.com/en/"
  url "https://github.com/pingcap/tidb.git",
      :tag      => "v2.1.13",
      :revision => "6b5b1a6802f9b8f5a22d8aab24ac80729331e1bc"

  depends_on "go" => :build

  def install
    # Change the default datadir
    inreplace "config/config.go", "/tmp/tidb", var/"tidb"
    inreplace "tidb-server/main.go", "/tmp/tidb", var/"tidb"

    # Removing the go.sum file
    # fixes a problem in go mod hashes:
    # https://stackoverflow.com/questions/54133789/go-modules-checksum-mismatch
    rm "go.sum"
    system "make", "server"
    bin.install "bin/tidb-server"
  end

  def caveats
    s = <<~EOS
      This install of TiDB uses goleveldb as the storage engine instead of TiKV,
      and is slower than a production install. Any benchmarks will be unreliable.

      tidb-server does not bundle any clients. To use the MySQL client:
      brew install mysql-client

      Security notice:
      This formula deliberately installs no launchd service. TiDB bootstraps a
      single all-privileged 'root'@'%' account with an empty password and has no
      option to set one non-interactively, so an auto-starting, login-persistent
      service would expose that account at every login. Start TiDB yourself,
      bound to loopback with the unauthenticated status HTTP service disabled
      (2.1 has no --status-host flag, so its status HTTP service always listens
      on every interface and can only be turned off):

        tidb-server --host 127.0.0.1 --report-status=false

      In another terminal, set a root password, move root off the wildcard host,
      and create a least-privileged account for applications:

        mysql -h 127.0.0.1 -P4000 -uroot
        SET PASSWORD FOR 'root'@'%' = 'choose-a-strong-root-password';
        CREATE USER 'root'@'127.0.0.1' IDENTIFIED BY 'choose-a-strong-root-password';
        CREATE USER 'app'@'127.0.0.1' IDENTIFIED BY 'choose-a-strong-app-password';
        GRANT SELECT, INSERT, UPDATE, DELETE ON yourdb.* TO 'app'@'127.0.0.1';
        DROP USER 'root'@'%';

      Dropping 'root'@'%' leaves root reachable only from loopback. If you must
      reach TiDB from another machine, prefer an SSH tunnel
      (ssh -L 4000:127.0.0.1:4000 this-host) over binding to 0.0.0.0.
    EOS
    s
  end

  test do
    begin
      dir = Dir.mktmpdir

      pid = fork do
        # Bind to loopback and skip the status HTTP service so `brew test` never
        # publishes the server or collides with a running instance on :10080.
        exec bin/"tidb-server", "--host", "127.0.0.1", "--report-status=false",
             "-P", "3999", "-path", dir
      end
      sleep 2

      output = shell_output("curl 127.0.0.1:3999")
      output.force_encoding("ASCII-8BIT") if output.respond_to?(:force_encoding)
      assert_match "5.7.25", output # MySQL 5.7
    ensure
      Process.kill(9, pid)
      Process.wait(pid)
    end
  end
end
