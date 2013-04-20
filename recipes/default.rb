# Build a clone of npmjs.org, per https://github.com/isaacs/npmjs.org

include_recipe "couchdb"
include_recipe "nodejs"
include_recipe "nodejs::npm"

package "curl"
package "git"

execute "Create registry" do
  command <<-EOF
    curl -X PUT http://localhost:#{node.couch_db.config.httpd.port}/registry
  EOF
end

execute "Install couchapp and semver" do
  command <<-EOF
  npm install couchapp -g
  npm install couchapp
  npm install semver
  EOF
end

# TODO: Work out how to do this without it timing out?
execute "Replicate npm's couchdb" do
  command <<-EOF
    curl --request POST --max-time 1 --silent --header "Content-Type:application/json" \
        http://localhost:#{node.couch_db.config.httpd.port}/_replicate -d \
        '{"source":"http://isaacs.iriscouch.com/registry/", "target":"registry"}'
  EOF
  returns 28
end

git "/srv/npmjs.org" do
  repository "https://github.com/isaacs/npmjs.org.git"
  enable_submodules true
end

execute "Sync the registry and search" do
  cwd "/srv/npmjs.org"
  command <<-EOF
  couchapp push registry/app.js http://localhost:#{node.couch_db.config.httpd.port}/registry
  couchapp push www/app.js http://localhost:#{node.couch_db.config.httpd.port}/registry
  EOF
  # HACK: couchapp errors, but pushes successfully
  # events.js:72
  #         throw er; // Unhandled 'error' event
  #               ^
  # Error: spawn ENOENT
  #     at errnoException (child_process.js:945:11)
  #     at Process.ChildProcess._handle.onexit (child_process.js:736:34)
  returns 8
end
