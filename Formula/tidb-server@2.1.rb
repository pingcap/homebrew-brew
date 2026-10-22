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
      `brew services start tidb-server` binds the MySQL protocol listener to
      127.0.0.1:4000 and runs as you rather than as root. 2.1 has no
      --status-host flag: its status/metrics HTTP service always listens on
      every interface, so the service disables it with --report-status=false.

      TiDB still bootstraps a single all-privileged 'root'@'%' account with an
      empty password and has no option to set one non-interactively, so anyone
      with local access can log in as root, and brew services re-exposes it at
      every login. Set a password and move root off the wildcard host now:

        mysql -h 127.0.0.1 -P4000 -uroot
        SET PASSWORD FOR 'root'@'%' = 'choose-a-strong-root-password';
        CREATE USER 'root'@'127.0.0.1' IDENTIFIED BY 'choose-a-strong-root-password';
        GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
        CREATE USER 'app'@'127.0.0.1' IDENTIFIED BY 'choose-a-strong-app-password';
        GRANT SELECT, INSERT, UPDATE, DELETE ON yourdb.* TO 'app'@'127.0.0.1';
        DROP USER 'root'@'%';

      The GRANT keeps 'root'@'127.0.0.1' administrative, so dropping the wildcard
      account does not lock you out. To run TiDB by hand, use the same flags:
      tidb-server --host 127.0.0.1 --report-status=false

      To reach TiDB from another machine, prefer an SSH tunnel
      (ssh -L 4000:127.0.0.1:4000 this-host) over binding to 0.0.0.0.
    EOS
    s
  end

  plist_options :manual => "tidb-server --host 127.0.0.1 --report-status=false"

  # launchd only honours UserName for system daemons, and there it is what keeps
  # the job off root. An empty or root value defeats that, and the value is
  # interpolated into XML, so validate and escape it.
  def tidb_service_user
    user = ENV["SUDO_USER"] || ENV["USER"]
    if user.nil? || user.empty? || user == "root"
      raise "refusing to run tidb-server as root; run `brew services` as your own account"
    end

    user.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

  # TiDB defaults --host to 0.0.0.0, which would publish a passwordless,
  # all-privileged 'root' account to the local network. 2.1 also has no
  # --status-host flag, so its unauthenticated status/metrics/pprof HTTP service
  # cannot be pinned to loopback and is disabled here instead of left on
  # 0.0.0.0:10080. UserName keeps the job off root even if it is installed as a
  # system daemon with `sudo`.
  def plist
    s = <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
        <true/>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/tidb-server</string>
          <string>--host</string>
          <string>127.0.0.1</string>
          <string>--report-status=false</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>UserName</key>
        <string>#{tidb_service_user}</string>
      </dict>
      </plist>
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
