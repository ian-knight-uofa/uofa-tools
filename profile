export UOFA_TOOLS_DIR=/tmp/uofa-tools
export VNU_DIR=/tmp/vnu
export NPM_CONFIG_PREFIX=~/.npm
export PORT=8080

export PATH=$UOFA_TOOLS_DIR/usr/bin:$UOFA_TOOLS_DIR/usr/sbin:$HOME/.npm/bin:$PATH
export LD_LIBRARY_PATH=$UOFA_TOOLS_DIR/usr/lib/mysql/plugin:$UOFA_TOOLS_DIR/usr/lib/mysql/private:$UOFA_TOOLS_DIR/usr/lib/mysql:$UOFA_TOOLS_DIR/usr/lib/x86_64-linux-gnu:$UOFA_TOOLS_DIR/usr/lib/mysql/plugin:$LD_LIBRARY_PATH

if [ ! "$(grep node_modules/ ~/.gitignore)" ]; then
  echo "node_modules/" >> .gitignore
fi

npm config set prefix '~/.npm'

function load_uofa_tools() {
    if [ ! -e $UOFA_TOOLS_DIR ]; then
        if [ ! -e ~/uofa-tools.zip ]; then
          curl -Lo ~/uofa-tools.zip https://github.com/ian-knight-uofa/uofa-tools/releases/download/21.03.01/uofa-tools.zip
        fi
        unzip -d /tmp ~/uofa-tools.zip
        echo -e "\nUofA Tools Setup\n\n\n\n\n\n"
    fi
}

function svn() {

    if [ "$(grep password ~/.subversion/auth/svn.simple/*)" ]; then
      rm -rf ~/.subversion/auth/svn.simple/*
      rm -rf ~/.c9/metadata/environment/.subversion/auth/svn.simple/*
      sqlite3 ~/.c9/*/collab.v3.db "DELETE FROM Revisions WHERE document_id IN (SELECT id FROM Documents WHERE path LIKE '%subversion/auth/svn.simple%'); DELETE FROM Documents WHERE path LIKE '%subversion/auth/svn.simple%';"
      echo -e '\nstore-passwords = no\nstore-ssl-client-cert-pp = no\nstore-plaintext-passwords = no\nstore-ssl-client-cert-pp-plaintext = no' >> ~/.subversion/servers
    fi

    # Add globally ignored files
    if [ ! "$(grep "^global-ignores.*" ~/.subversion/config)" ]; then
        sed -i 's/# global-ignores.*/global-ignores = *.o *.lo *.la *.al .libs *.so *.so.[0-9]* *.a *.pyc *.pyo __pycache__ node_modules .*.swp .DS_Store [Tt]humbs.db /' ~/.subversion/config
    fi

    # Install SVN
    load_uofa_tools

    args=( "$@" )
    command svn "${args[@]}"

}

function express() {

    if [ ! "$(type -f express)" ]; then
      npm install --prefix=$HOME/.npm -g express-generator
      echo -e "\nExpress Generator Installed\n\n\n\n\n\n"
    fi

    args=( "$@" )
    argc="${#args[@]}"
    if [ $argc -gt 0 ]; then
        command express "${args[@]}"
    else
        command express --no-view
    fi

}

function eslint() {

    if [ ! "$(type -f eslint)" ]; then
      npm install --prefix=$HOME/.npm -g eslint
      echo -e "\nESLint Installed\n\n\n\n\n\n"
    fi

    args=( "$@" )
    command eslint "${args[@]}"

}

function vnu() {

    if [ ! -e $VNU_DIR ]; then
        if [ ! -e ~/vnu.jar.zip ]; then
          curl -Lo ~/vnu.jar.zip https://github.com/validator/validator/releases/download/20.6.30/vnu.jar_20.6.30.zip
        fi
        unzip -d /tmp ~/vnu.jar.zip
        mv /tmp/dist $VNU_DIR
        echo -e "\nvNU Setup\n\n\n\n\n\n"
    fi

    args=( "$@" )
    java -jar /tmp/vnu/vnu.jar "${args[@]}"

}

export SQLDATDIR=/home/ubuntu/sql_data
export SQLTMPDIR=/tmp/sql_files

# WDC SQL Server Setup Script -- v2.0 January 2020
# Written by Ian Knight

# Function to reset sql server
function sql_reset() {
    sql_stop
    rm -rf $SQLTMPDIR
    rm -rf $SQLDATDIR
}

# Function to stop a running sql server
function sql_stop() {
    printf "\n\033[1mExiting...\033[0m\n"
    killall -SIGTERM mysqld
    # Wait up to 20s until sock & pid files removed
    COUNTER=0
    while [  $COUNTER -lt 20 ]; do
        if [ -e "$SQLTMPDIR/mysql.sock" -o -e "$SQLTMPDIR/mysql.pid" ]; then
            sleep 1
            ((COUNTER++))
        else
            COUNTER=20
        fi
    done
    printf "Don't forget to backup your Databases!\n"
    SQLPID=0
}

function sql_start() {

    # Install MySQL
    load_uofa_tools

    SQLINIT=0

    if [ ! -d "$SQLTMPDIR" ]; then
        # Setup tmpdir
        mkdir "$SQLTMPDIR"
        chmod 777 "$SQLTMPDIR"
    fi

    if [ ! -d "$SQLDATDIR" ]; then
        # Database not setup yet, do install
        mkdir "$SQLDATDIR"
        chmod 777 "$SQLDATDIR"
        printf '\n\033[1mInstalling SQL database files...\033[0m\n'
        mysqld_safe --initialize-insecure --log-error="$SQLTMPDIR/mysql.log" --basedir=$UOFA_TOOLS_DIR/usr --secure-file-priv="" --innodb_log_file_size=16M --innodb_log_group_home_dir="$SQLTMPDIR" --datadir="$SQLDATDIR" --user=$USER --pid-file="$SQLTMPDIR/mysql.pid" --socket="$SQLTMPDIR/mysql.sock"
        SQLINIT=1
    fi

    # Check if SQL Server running or exited uncleanly
    # Wait up to 20s until sock & pid files created
    printf 'Checking no existing sql processes running... '
    COUNTER=0
    STAGE=0
    while [  $COUNTER -lt 20 ]; do
        if [ -e "$SQLTMPDIR/mysql.sock" -o -e "$SQLTMPDIR/mysql.pid" ]; then

            if [ $STAGE = 0 -a $COUNTER = 0 ]; then
                printf '\n\033[1;91mSQL Server still running or exited uncleanly!\033[0m\n'
                printf 'Terminating existing sql processes... '
                killall -SIGTERM mysqld &> /dev/null
                STAGE=1
            elif [ $STAGE = 1 -a $COUNTER = 7 ]; then
                printf '\033[1;91mFAIL\033[0m\n'
                printf 'Forcibly killing existing sql processes... '
                killall -SIGKILL mysqld_safe &> /dev/null
                killall -SIGKILL mysqld &> /dev/null
                STAGE=2
            elif [ $STAGE = 2 -a $COUNTER = 15 ]; then
                printf '\033[1;91mFAIL\033[0m\n'
                printf 'Manually cleaning... '
                rm -f $SQLTMPDIR/mysql.sock $SQLTMPDIR/mysql.pid &> /dev/null
                STAGE=3
            elif [ $COUNTER = 19 ]; then
                printf '\033[1;93mUnsuccessful. If sql server does not start, restart your IDE.\033[0m\n\n'
            fi
            sleep 1
            ((COUNTER++))
        else
            printf ' \033[1;92mOK\033[0m \n\n'
            COUNTER=20
        fi
    done

    # Start SQL Server
    printf "\033[1mStarting SQL Server...\033[0m\n"
    mysqld_safe --no-defaults  --basedir=$UOFA_TOOLS_DIR/usr --secure-file-priv="" --datadir="$SQLDATDIR" --log-error="$SQLDATDIR/mysql.log" --lc-messages-dir=$UOFA_TOOLS_DIR/usr/share/mysql/english --innodb_log_file_size=16M --innodb_log_group_home_dir="$SQLTMPDIR" --pid-file="$SQLTMPDIR/mysql.pid" --socket="$SQLTMPDIR/mysql.sock" &
    #mysqld_safe --no-defaults --datadir="$SQLDATDIR" --log-error=mysql.log --pid-file=mysql.pid --socket=mysql.sock &
    SQLPID=$!

    # Wait up to 20s until sock & pid files created
    COUNTER=0
    while [  $COUNTER -lt 20 ]; do
        if [ -e "$SQLTMPDIR/mysql.sock" -a -e "$SQLTMPDIR/mysql.pid" ]; then
            COUNTER=20
        else
            sleep 1
            ((COUNTER++))
        fi
    done

    # If sock & pid files have been created running okay, else exit
    if [ -e "$SQLTMPDIR/mysql.sock" -a -e "$SQLTMPDIR/mysql.pid" ]; then
        if [ $SQLINIT = 1 ]; then
            # Finish initialising database
            printf '\033[1mFinalising install... \033[0m\nSetting up privileges... '
            echo -e "CREATE USER ''@'localhost'; GRANT ALL PRIVILEGES ON *.* TO ''@'localhost'; FLUSH PRIVILEGES;\n" | \
            mysql --no-defaults --socket="$SQLTMPDIR/mysql.sock" --user=root
            printf ' \033[1;92mOK\033[0m \n\n'
        fi
        printf "\033[1;92mSQL Server Running.\033[0m\nUse sql_stop to stop the server"
    else
        printf '\033[1;91mSQL Server Failed to start!\033[0m\n'
        sql_stop
    fi

}

export -f svn
export -f express
export -f eslint
export -f vnu
export -f sql_stop
export -f sql_start
export -f sql_reset
export -f load_uofa_tools
