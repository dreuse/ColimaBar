cask "colimabar" do
  version "0.1.0"
  sha256 "86e60ffe1f251db4e8f365cdaeb6003195750ebb38ff81f99d1dd5103e4a84c7"

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
