cask "colimabar" do
  version "0.3.0"
  sha256 "eaefc70aeb136457da59d569ac2f9e9b6d33a112803757228a60b2cb8a407794"

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
