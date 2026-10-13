class TidbServer < Formula
  desc "TiDB is a MySQL compatible distributed database"
  homepage "https://www.pingcap.com/en/"
  url "https://github.com/pingcap/tidb.git",
      :tag      => "v3.0.12",
      :revision => "8c4696b3f3408c61dd7454204ddd67c93501609a"

  depends_on "go" => :build

  def install
    # Change the default datadir
    inreplace "config/config.go", "/tmp/tidb", var/"tidb"
    inreplace "tidb-server/main.go", "/tmp/tidb", var/"tidb"

    system "make", "server"
    bin.install "bin/tidb-server"
  end

  def caveats
    s = <<~EOS
      This install of TiDB uses goleveldb as the storage engine instead of TiKV,
      and is slower than a production install. Any benchmarks will be unreliable.

      tidb-server does not bundle any clients. To use the MySQL client:
      brew install mysql-client
      mysql -h 127.0.0.1 -P4000 -uroot

      Security notice:
      The service binds both listeners to 127.0.0.1 only:
        MySQL protocol       127.0.0.1:4000
        Status/metrics HTTP  127.0.0.1:10080 (/metrics, /settings, /debug/pprof)

      TiDB bootstraps a single all-privileged account, 'root'@'%', with an empty
      password, and its status HTTP endpoints are unauthenticated. Anyone with
      local access to this machine can read and change any data as root. Set a
      root password and give applications a least-privileged account:

        mysql -h 127.0.0.1 -P4000 -uroot
        SET PASSWORD FOR 'root'@'%' = 'choose-a-strong-root-password';
        CREATE USER 'app'@'127.0.0.1' IDENTIFIED BY 'choose-a-strong-app-password';
        GRANT SELECT, INSERT, UPDATE, DELETE ON yourdb.* TO 'app'@'127.0.0.1';

      Running `tidb-server` by hand without --host 127.0.0.1 makes it listen on
      every interface. To reach TiDB from another machine, prefer an SSH tunnel
      (ssh -L 4000:127.0.0.1:4000 this-host) over rebinding to 0.0.0.0.

      Questions? https://pingcap.com/tidbslack/

    EOS
    s
  end

  plist_options :manual => "tidb-server --host 127.0.0.1 --status-host 127.0.0.1"

  # TiDB defaults both --host and --status-host to 0.0.0.0, which would publish
  # a passwordless, all-privileged 'root' account and an unauthenticated
  # status/metrics/pprof HTTP endpoint to the local network. Pin them to
  # loopback here so `brew services start tidb-server` is safe by default.
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
          <string>--status-host</string>
          <string>127.0.0.1</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
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
