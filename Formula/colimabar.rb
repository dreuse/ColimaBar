cask "colimabar" do
  version "0.3.2"
  sha256 "55566899d06de0312ca1c5a7ee06812b21b4058988bd9c5f0461e2caf8c0a746"

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
