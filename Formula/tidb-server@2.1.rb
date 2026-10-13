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
      mysql -h 127.0.0.1 -P4000 -uroot

      Security notice:
      The service binds the MySQL protocol listener to 127.0.0.1:4000 only.

      TiDB 2.1 has no --status-host flag: its status/metrics HTTP service always
      listens on every interface (:10080), so this formula disables that service
      with --report-status=false. TiDB also bootstraps a single all-privileged
      account, 'root'@'%', with an empty password, so anyone with local access
      to this machine can read and change any data as root. Set a root password
      and give applications a least-privileged account:

        mysql -h 127.0.0.1 -P4000 -uroot
        SET PASSWORD FOR 'root'@'%' = 'choose-a-strong-root-password';
        CREATE USER 'app'@'127.0.0.1' IDENTIFIED BY 'choose-a-strong-app-password';
        GRANT SELECT, INSERT, UPDATE, DELETE ON yourdb.* TO 'app'@'127.0.0.1';

      Running `tidb-server` by hand without --host 127.0.0.1 makes it listen on
      every interface. To reach TiDB from another machine, prefer an SSH tunnel
      (ssh -L 4000:127.0.0.1:4000 this-host) over rebinding to 0.0.0.0.
    EOS
    s
  end

  plist_options :manual => "tidb-server --host 127.0.0.1 --report-status=false"

  # TiDB defaults --host to 0.0.0.0, which would publish a passwordless,
  # all-privileged 'root' account to the local network. 2.1 also has no
  # --status-host flag, so its unauthenticated status/metrics/pprof HTTP service
  # cannot be pinned to loopback and is disabled here instead of left on
  # 0.0.0.0:10080.
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
