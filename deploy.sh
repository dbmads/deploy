#!/bin/bash
# Setup deployment target for Nginx + Python/uWSGI + Supervisor + Git


function usage() {
    cat << EOF
Usage: $0 [-y] PROJECT_NAME [DOMAIN]

Options:
    -y    No prompts, assume yes to all.

Example:
    $0 -y foo fooapp.com
EOF
}

while getopts "h:y" OPTION; do
     case $OPTION in
         h)
             usage
             exit
             ;;
         y)
             NOPROMPT="y"
             shift
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

PROJECTNAME="$1"
DOMAIN="$2"
USERNAME="$(whoami)"

if [ "$USERNAME" == "root" ]; then
    echo "Error: Must be run as non-root."
    exit 2
fi

if [ ! "$PROJECTNAME" ]; then
    echo "Error: Must specify a project name."
    exit 3;
fi

if [ ! "$DOMAIN" ]; then
    DOMAIN="$PROJECTNAME.com"
fi

if [ "$NOPROMPT" != "y" ]; then
    echo "This script is intended to be run on a remote server, not on a local development environment. It will create a bunch of directories and change a bunch of configurations."
    read -n1 -p "Are you sure you want to continue? [y/N] " answer
    if [ "$answer" != "y" ]; then
        echo "Aborting."
        exit 4
    fi
fi

# Setup our directory structure
mkdir ~/{deploy,env,logs,public_html,repo,uploads}
mkdir ~/{repo,logs,public_html,uploads}/$PROJECTNAME


# Create a detached tree repository
cd ~/repo/$PROJECTNAME
git init --bare
git config core.bare false
#git config core.worktree ~/deploy/$PROJECTNAME
git config receive.denycurrentbranch ignore

git clone  ~/repo/$PROJECTNAME ~/deploy/$PROJECTNAME


# Setup post-receive hook to update detached tree on receive
cat > hooks/post-receive << EOF
#!/bin/sh
WORK_DIR=/home/$USERNAME/deploy/$PROJECTNAME
DEPLOY_LOG=/home/$USERNAME/deploy/deploy-$PROJECTNAME.log
echo === \`date\`  === | tee -a  \$DEPLOY_LOG
git --git-dir \$WORK_DIR/.git --work-tree \$WORK_DIR pull origin | tee -a \$DEPLOY_LOG

UWSGI_PID=/tmp/$PROJECTNAME-uwsgi.pid
if [ -f "\$UWSGI_PID" ]; then
        echo "Restarting uwsgi.";
        kill -HUP \$(cat \$UWSGI_PID);
fi

EOF

chmod +x hooks/post-receive


# Setup static assets to be served by nginx directly
ln -s ~/deploy/$PROJECTNAME/static ~/public_html/$PROJECTNAME/static


# Virtualenv
virtualenv ~/env/$PROJECTNAME
source ~/env/$PROJECTNAME/bin/activate


# Install root config files

## Supervisor
sudo tee /etc/supervisor/conf.d/$PROJECTNAME.conf > /dev/null << EOF
[program:$PROJECTNAME-uwsgi]
directory=/home/$USERNAME/deploy/$PROJECTNAME
user=$USERNAME

command=/usr/bin/uwsgi_python -C -H /home/$USERNAME/env/$PROJECTNAME -L -w wsgi --socket /tmp/$PROJECTNAME-uwsgi.sock --master --processes 4 --pidfile  /tmp/$PROJECTNAME-uwsgi.pid --module $PROJECTNAME --callable app --harakiri=20 --limit-as=128 --max-requests=5000 --vacuum
stdout_logfile=/home/$USERNAME/logs/$PROJECTNAME/uwsgi.log

redirect_stderr=true
stopsignal=INT
autorestart=true
EOF

## Nginx
sudo tee /etc/nginx/sites-available/$PROJECTNAME > /dev/null << EOF
server {
        listen   80;
        server_name  $DOMAIN;
        access_log  /home/$USERNAME/logs/$PROJECTNAME/access.log;
        charset utf-8;

        gzip on;
        gzip_http_version 1.1;
        gzip_vary on;
        gzip_comp_level 6;
        gzip_proxied any;
        gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
        gzip_buffers 16 8k;
        gzip_disable "MSIE [1-6].(?!.*SV1)";

        location ~ ^/(robots.txt|favicon.ico)\$ {
                root /home/$USERNAME/public_html/$PROJECTNAME/static;
        }

        location /static {
                root   /home/$USERNAME/public_html/$PROJECTNAME/;
                expires max;
                add_header Cache-Control "public";
        }

        location / {
                include uwsgi_params;
                uwsgi_pass unix:///tmp/$PROJECTNAME-uwsgi.sock;
                uwsgi_param SCRIPT_NAME "";
        }

}

server {
        listen  80;
        server_name www.$DOMAIN;
        rewrite ^/(.*) http://$DOMAIN/\$1 permanent;
}
EOF

## Enable new Nginx config
sudo ln -sft /etc/nginx/sites-enabled/ "../sites-available/$PROJECTNAME"

# Restart things

sudo service nginx restart
sudo service supervisor stop
sudo service supervisor start


# Print instructions

IP_ADDRESS="$(/sbin/ifconfig eth0 | awk -F: '/inet addr:/ {print $2}' | awk '{ print $1 }')"

cat << EOF
Setup your development clone as follows:

    git branch live
    git remote add -t live live ssh://$USERNAME@$IP_ADDRESS/home/$USERNAME/repo/$PROJECTNAME

Now you can deploy:

    git checkout live
    git merge master
    git checkout master
    git push live

Or use this handy 'deploy' alias in your ~/.gitconfig file:

    deploy = "!merge(){ git checkout \$2 && git merge \$1 && git push \$2 && git checkout \${1#refs/heads/}; }; merge \$(git symbolic-ref HEAD) \$1"

So you can do (from 'master'):

    git deploy live

Happy pushing!
EOF
