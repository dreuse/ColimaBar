cask "colimabar" do
  version "0.1.0"
  sha256 "PLACEHOLDER_SHA256"

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
