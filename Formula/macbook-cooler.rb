class MacbookCooler < Formula
  desc "Thermal management scripts for Apple Silicon MacBook Pro"
  homepage "https://github.com/nelsojona/macbook-cooler"
  url "https://github.com/nelsojona/macbook-cooler/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "d5558cd419c8d46bdc958064cb97f963d1ea793866414c025906ec15033512ed"
  license "MIT"
  head "https://github.com/nelsojona/macbook-cooler.git", branch: "main"

  depends_on :macos

  def install
    libexec.install Dir["scripts/*.sh"]
    libexec.install Dir["scripts/*.conf"]

    (libexec/"thermal_monitor.sh").chmod 0755
    (libexec/"auto_power_mode.sh").chmod 0755
    (libexec/"thermal_throttle.sh").chmod 0755
    (libexec/"thermal_scheduler.sh").chmod 0755
    (libexec/"fan_control.sh").chmod 0755
    (libexec/"system_optimizer.sh").chmod 0755

    (bin/"thermal-monitor").write_env_script libexec/"thermal_monitor.sh", {}
    (bin/"thermal-power").write_env_script libexec/"auto_power_mode.sh", {}
    (bin/"thermal-throttle").write_env_script libexec/"thermal_throttle.sh", {}
    (bin/"thermal-schedule").write_env_script libexec/"thermal_scheduler.sh", {}
    (bin/"thermal-fan").write_env_script libexec/"fan_control.sh", {}
    (bin/"thermal-optimize").write_env_script libexec/"system_optimizer.sh", {}

    etc.install libexec/"thermal_config.conf" => "thermal-management/thermal_config.conf"
    (var/"log/thermal-management").mkpath
  end

  def caveats
    <<~EOS
      Thermal Management Suite has been installed!

      Most commands require sudo to access system metrics:
        sudo thermal-monitor
        sudo thermal-power --daemon

      Configuration file is located at:
        #{etc}/thermal-management/thermal_config.conf

      Logs are stored in:
        #{var}/log/thermal-management/

      To start the auto power mode service:
        brew services start macbook-cooler

      For more information, run:
        thermal-monitor --help
    EOS
  end

  service do
    run [opt_bin/"thermal-power", "--daemon"]
    keep_alive true
    log_path var/"log/thermal-management/power_service.log"
    error_log_path var/"log/thermal-management/power_service_error.log"
  end

  test do
    assert_match "Thermal Monitor", shell_output("#{bin}/thermal-monitor --help")
  end
end
