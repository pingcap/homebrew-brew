class TidbServer < Formula
  desc "TiDB is a MySQL compatible distributed database"
  homepage "https://www.pingcap.com/en/"
  url "https://github.com/pingcap/tidb.git",
      :tag      => "v26.3.21",
      :revision => "4bf5d42345b96340f888e7ef87aa83741aaa1832"

  depends_on "go" => :build

  def install
    # Keep the data directory under Homebrew's var; the socket template stays in
    # /tmp so auth_socket logins keep working.
    inreplace "pkg/config/config.go" do |s|
      s.gsub!(/Path:\s+"\/tmp\/tidb"/, "Path: \"#{var}/tidb\"")
    end
    inreplace "cmd/tidb-server/main.go" do |s|
      s.gsub!('storePath = fset.String(nmStorePath, "/tmp/tidb",',
              "storePath = fset.String(nmStorePath, \"#{var}/tidb\",")
    end

    system "make", "server"
    bin.install "bin/tidb-server"
  end

  def caveats
    s = <<~EOS
      This install of TiDB uses the built-in mocktikv/unistore engine instead of
      TiKV, and is slower than a production install. Any benchmarks will be
      unreliable.

      tidb-server does not bundle any clients. To use the MySQL client:
      brew install mysql-client

      Security notice:
      `brew services start tidb-server` runs with --initialize-secure, so a fresh
      datastore bootstraps 'root'@'localhost' with the auth_socket plugin: no
      password, usable only over the Unix socket, and only by the OS user that
      started the server. There is no wildcard root, and the unauthenticated
      status HTTP service is disabled.

        mysql -S /tmp/tidb-4000.sock -uroot

      A datastore created by an older formula was bootstrapped insecurely and is
      not migrated automatically. For those, drop the wildcard root (the GRANT
      keeps the replacement administrative):

        mysql -h 127.0.0.1 -P4000 -uroot
        SET PASSWORD FOR 'root'@'%' = 'choose-a-strong-root-password';
        CREATE USER 'root'@'127.0.0.1' IDENTIFIED BY 'choose-a-strong-root-password';
        GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
        DROP USER 'root'@'%';

      Give applications a least-privileged account in either case:

        CREATE USER 'app'@'127.0.0.1' IDENTIFIED BY 'choose-a-strong-app-password';
        GRANT SELECT, INSERT, UPDATE, DELETE ON yourdb.* TO 'app'@'127.0.0.1';

      To reach TiDB from another machine, prefer an SSH tunnel
      (ssh -L 4000:127.0.0.1:4000 this-host) over binding to 0.0.0.0.

      Questions? https://pingcap.com/tidbslack/

    EOS
    s
  end

  plist_options :manual => "tidb-server --host 127.0.0.1 --report-status=false --initialize-secure"

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

  # TiDB defaults --host to 0.0.0.0 and always serves an unauthenticated
  # status/pprof HTTP endpoint whose /settings and /reload-config handlers mutate
  # configuration. Pin the database to loopback, switch the status service off,
  # and bootstrap credentials securely. UserName keeps the job off root even if
  # it is installed as a system daemon with `sudo`.
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
          <string>--initialize-secure</string>
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
        # Bind to loopback, skip the status HTTP service, and bootstrap securely
        # so `brew test` never publishes an unauthenticated server.
        exec bin/"tidb-server", "--host", "127.0.0.1", "--report-status=false",
             "--initialize-secure", "-P", "3999", "-path", dir
      end

      require "socket"
      handshake = nil
      30.times do
        begin
          TCPSocket.open("127.0.0.1", 3999) { |sock| handshake = sock.readpartial(128) }
          break
        rescue SystemCallError, IOError
          sleep 1
        end
      end

      assert_match "8.0.11", handshake.to_s # MySQL 8.0 compatibility
    ensure
      Process.kill(9, pid)
      Process.wait(pid)
    end
  end
end
