class TidbServer < Formula
  desc "TiDB is a MySQL compatible distributed database"
  homepage "https://www.pingcap.com/en/"
  url "https://github.com/pingcap/tidb.git",
      :tag      => "v26.3.21",
      :revision => "4bf5d42345b96340f888e7ef87aa83741aaa1832"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :git
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on "go" => :build

  def install
    # Make the compiled-in defaults safe too, not just the service flags: data
    # and the default socket move under Homebrew's var, listeners default to
    # loopback, the status HTTP service is off, and bootstrap is secure.
    inreplace "pkg/config/config.go" do |s|
      unless s.gsub!(/Path:\s+"\/tmp\/tidb"/, "Path: \"#{var}/tidb-26\"") &&
             s.gsub!('"/tmp/tidb-{Port}.sock"', "\"#{var}/tidb.sock\"") &&
             s.gsub!('DefHost = "0.0.0.0"', 'DefHost = "127.0.0.1"') &&
             s.gsub!('DefStatusHost = "0.0.0.0"', 'DefStatusHost = "127.0.0.1"') &&
             s.gsub!(/ReportStatus:\s+true/, "ReportStatus: false") &&
             s.gsub!("Security: Security{", "Security: Security{\n\t\tSecureBootstrap: true,")
        raise "could not harden the default config in pkg/config/config.go"
      end
    end
    inreplace "cmd/tidb-server/main.go" do |s|
      unless s.gsub!('storePath = fset.String(nmStorePath, "/tmp/tidb",',
                     "storePath = fset.String(nmStorePath, \"#{var}/tidb-26\",") &&
             s.gsub!('socket = fset.String(nmSocket, "/tmp/tidb-{Port}.sock"',
                     "socket = fset.String(nmSocket, \"#{var}/tidb.sock\"") &&
             s.gsub!('host = fset.String(nmHost, "0.0.0.0",',
                     'host = fset.String(nmHost, "127.0.0.1",') &&
             s.gsub!('statusHost = fset.String(nmStatusHost, "0.0.0.0",',
                     'statusHost = fset.String(nmStatusHost, "127.0.0.1",') &&
             s.gsub!('reportStatus = flagBoolean(fset, nmReportStatus, true,',
                     'reportStatus = flagBoolean(fset, nmReportStatus, false,')
        raise "could not harden the default flags in cmd/tidb-server/main.go"
      end
    end

    system "make", "server"
    bin.install "bin/tidb-server"
  end

  def post_install
    return unless (var/"tidb").exist?

    opoo <<~EOS
      A datastore from an older formula was found at #{var}/tidb. This version
      uses #{var}/tidb-26 and never opens the old store, so its accounts are not
      reachable; see `brew info tidb-server` if you want to migrate it.
    EOS
  end

  def caveats
    s = <<~EOS
      This install of TiDB uses the built-in unistore engine instead of TiKV,
      and is slower than a production install. Any benchmarks will be unreliable.

      tidb-server does not bundle any clients. To use the MySQL client:
      brew install mysql-client

      Security notice:
      A fresh datastore is bootstrapped securely: 'root'@'localhost' uses the
      auth_socket plugin, so it has no password, only works over the Unix socket
      below, and only for the OS user that started the server. There is no
      wildcard root, and the unauthenticated status HTTP service is disabled.

        mysql -S #{var}/tidb.sock -uroot

      Data lives in #{var}/tidb-26. A datastore left at #{var}/tidb by an
      older formula is never opened by this service. v3.0/v2.1 stores use a
      different engine, so export them with the matching version. A v26 store
      can be reopened deliberately on a separate, loopback-only port and socket:

        tidb-server --host 127.0.0.1 --store unistore --path #{var}/tidb \
          -P 4001 --socket #{var}/tidb-migrate.sock --report-status=false

      Connect interactively (never put a password on a command line) and run,
      replacing the placeholders with values you choose:

        mysql -S #{var}/tidb-migrate.sock -uroot

        SET PASSWORD FOR 'root'@'%' = '<root-password>';
        CREATE USER 'root'@'127.0.0.1' IDENTIFIED BY '<root-password>';
        GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
        DROP USER 'root'@'%';

      Give applications a least-privileged account, again typed interactively:

        mysql -S #{var}/tidb.sock -uroot

        CREATE USER 'app'@'127.0.0.1' IDENTIFIED BY '<app-password>';
        GRANT SELECT, INSERT, UPDATE, DELETE ON yourdb.* TO 'app'@'127.0.0.1';

      To reach TiDB from another machine, prefer an SSH tunnel
      (ssh -L 4000:127.0.0.1:4000 this-host) over binding to 0.0.0.0.

      Questions? https://pingcap.com/tidbslack/

    EOS
    s
  end

  # The service definition lives in Homebrew's supported DSL so the hardening is
  # carried by the generated unit rather than by a deprecated hand-written plist.
  # The socket is moved out of world-writable /tmp into the (user-owned) var
  # directory, and stdout/stderr are recorded for auditing.
  service do
    run [opt_bin/"tidb-server", "--host", "127.0.0.1", "--store", "unistore",
         "--socket", "#{var}/tidb.sock", "--report-status=false",
         "--initialize-secure"]
    keep_alive true
    run_at_load true
    require_root false
    working_dir var
    log_path var/"log/tidb-server.log"
    error_log_path var/"log/tidb-server.err.log"
  end

  test do
    begin
      dir = Dir.mktmpdir

      pid = fork do
        # Bind to loopback, keep the socket out of /tmp, skip the status HTTP
        # service, and bootstrap securely.
        exec bin/"tidb-server", "--host", "127.0.0.1", "--store", "unistore",
             "--socket", "#{dir}/tidb.sock", "--report-status=false",
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
