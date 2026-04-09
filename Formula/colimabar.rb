cask "colimabar" do
  version "0.3.4"
  sha256 "c005430264e395525ada75a8386026320ca25cb15d71ea46eb248082cf8920af"

  url "https://github.com/dreuse/ColimaBar/releases/download/v#{version}/ColimaBar.zip"
  name "ColimaBar"
  desc "Menu bar app for managing Colima container profiles"
  homepage "https://github.com/dreuse/ColimaBar"

  depends_on macos: ">= :ventura"
  depends_on formula: "colima"

  app "ColimaBar.app"

  zap trash: [
    "~/Library/Preferences/dev.dreuse.ColimaBar.plist",
    "~/Library/Caches/dev.dreuse.ColimaBar",
  ]
end
