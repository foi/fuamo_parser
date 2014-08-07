require './server.rb'
use Rack::MethodOverride
map "/public" do
  run Rack::Directory.new("./public")
end
run Fuamo