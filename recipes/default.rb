# Build a clone of npmjs.org, per https://github.com/isaacs/npmjs.org

include_recipe "couchdb"

# HACK: Force couch to start cleanly
#       When we first install couch and boot the machine, couch starts in a weird, broken state. Notably, it listens on localhost instead of *. This hack kills it and starts again. There's probably a better way to do this. Also need to look into fixing the goddamn cookbook.
execute 'Force couch to start cleanly' do
  # HACK: Assume couch is runnning under beam
  #       Could be other things running under this, too, but fuck it for now.
  command "pkill beam"
  not_if "netstat -lp --inet | grep *:5984"
  notifies :start, "service[couchdb]", :immediate
end

# HACK: Couch isn't ready yet, even though it's 'started'. Sigh.
execute "wait for couchdb" do
  command "sleep 5"
end

package "curl"
package "git"

execute "Create registry" do
  command <<-EOF
    curl -X PUT http://localhost:#{node.couch_db.config.httpd.port}/registry
  EOF
end

execute "Replicate npm's couchdb" do
  command <<-EOF
    curl --request POST --max-time 1 --silent --header "Content-Type:application/json" \
        http://localhost:#{node.couch_db.config.httpd.port}/_replicate -d \
        '{"source":"http://isaacs.iriscouch.com/registry/", "target":"registry"}'
  EOF
  returns 28
end

include_recipe "nodejs::npm"

execute "Install couchapp and semver" do
  command <<-EOF
    npm install couchapp -g
    npm install couchapp
    npm install semver
  EOF
end

package "git"
git "/srv/npmjs.org" do
  repository "https://github.com/isaacs/npmjs.org.git"
end

execute "Sync the registry-rewriter and search UI" do
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
 #     at Process.ChildProcess._handle.onexit (child_process.js:736:
 returns 8
end
