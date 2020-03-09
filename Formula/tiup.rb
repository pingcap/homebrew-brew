class Tiup < Formula
  desc "TiDB is a MySQL compatible distributed database, and tiup is a component manager for testing and using TiDB locally."
  homepage "https://www.pingcap.com/en/"
  url "https://github.com/pingcap-incubator/tiup.git",
    :tag => "v0.0.1"

  depends_on "go" => :build
  depends_on "mysql-client" => :optional

  def install
    system "make", "EXTRA_LDFLAGS=-X \"github.com/pingcap-incubator/tiup/pkg/localdata.DefaultTiupHome=#{var}/tiup\"", "cmd"
    bin.install "bin/tiup"
  end

  def caveats
    s = <<~EOS

      To get started running a full TiDB Platform stack, with
      TiDB Server, TiKV Server, and PD, use tiup playground:

        tiup run playground

      Questions? https://pingcap.com/tidbslack/

    EOS
    s
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! For Homebrew/homebrew-core
    # this will need to be a test that verifies the functionality of the
    # software. Run the test with `brew test tiup`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system "false"
  end
end
