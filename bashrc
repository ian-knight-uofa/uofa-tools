export VNU_DIR=/home/ubuntu/vnu
export PORT=8080

function express() {

    if [ ! "$(type -f express)" ]; then
      sudo npm install -g express-generator
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
      sudo npm install -g eslint
      echo -e "\nESLint Installed\n\n\n\n\n\n"
    fi

    args=( "$@" )
    command eslint "${args[@]}"

}

function vnu() {

    if [ ! -e $VNU_DIR ]; then
        if [ ! -e /tmp/vnu.jar.zip ]; then
          curl -Lo /tmp/vnu.jar.zip https://github.com/validator/validator/releases/download/20.6.30/vnu.jar_20.6.30.zip
        fi
        unzip -d /tmp /tmp/vnu.jar.zip
        mv /tmp/dist $VNU_DIR
        echo -e "\nvNU Setup\n\n\n\n\n\n"
    fi

    args=( "$@" )
    java -jar $VNU_DIR/vnu.jar "${args[@]}"

}

export SQLDATDIR=/home/ubuntu/sql_data
export SQLTMPDIR=/tmp/sql_files

# WDC SQL Server Setup Script -- v2.2 March 2022
# Written by Ian Knight

# Function to reset sql server
function sql_reset() {
    read -p "This reset will delete any exisiting sql databases. Do you wish to continue? (y or cancel)" -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sql_stop
        echo "Cleanup ..."
        rm -rf $SQLTMPDIR
        rm -rf $SQLDATDIR
    else
        echo "Cancelled."
    fi
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
    if [ ! "$(command -v mysqld_safe)" ]; then
      sudo apt install -y mysql-server
      echo -e "\nSQL Server Installed\n\n\n\n\n\n"
    fi

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
        mysqld_safe --initialize-insecure --log-error="$SQLTMPDIR/mysql.log" --secure-file-priv="" --performance_schema=OFF --innodb_log_file_size=8M --innodb_log_group_home_dir="$SQLTMPDIR" --datadir="$SQLDATDIR" --user=$USER --pid-file="$SQLTMPDIR/mysql.pid" --socket="$SQLTMPDIR/mysql.sock"
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
    mysqld_safe --no-defaults --secure-file-priv="" --default-authentication-plugin=mysql_native_password --performance_schema=OFF --datadir="$SQLDATDIR" --log-error="$SQLDATDIR/mysql.log" --innodb_log_file_size=8M --innodb_log_group_home_dir="$SQLTMPDIR" --pid-file="$SQLTMPDIR/mysql.pid" --socket="$SQLTMPDIR/mysql.sock" &
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
        printf "\033[1;92mSQL Server Running.\033[0m\nUse sql_stop to stop the server\n"
    else
        printf '\033[1;91mSQL Server Failed to start!\033[0m\n'
        sql_stop
    fi

}

function juice_shop() {

    (
        export NODE_ENV=unsafe
        export JUICE_DIR=~/juice-shop

        if [ ! -e $JUICE_DIR ]; then
            if [ ! -e ~/juice-shop.tar.gz ]; then
                if node --version | grep v18 > /dev/null ; then
                    echo "Node 18 detected."
                    curl -Lo ~/juice-shop.tar.gz https://github.com/juice-shop/juice-shop/releases/download/v14.0.1/juice-shop-14.0.1_node18_linux_x64.tgz
                elif node --version | grep v17 > /dev/null ; then
                    echo "Node 17 detected."
                    curl -Lo ~/juice-shop.tar.gz https://github.com/juice-shop/juice-shop/releases/download/v13.3.0/juice-shop-13.3.0_node17_linux_x64.tgz
                elif node --version | grep v16 > /dev/null ; then
                    echo "Node 16 detected."
                    curl -Lo ~/juice-shop.tar.gz https://github.com/juice-shop/juice-shop/releases/download/v14.0.1/juice-shop-14.0.1_node16_linux_x64.tgz
                elif node --version | grep v14 > /dev/null ; then
                    echo "Node 14 detected."
                    curl -Lo ~/juice-shop.tar.gz https://github.com/juice-shop/juice-shop/releases/download/v14.0.1/juice-shop-14.0.1_node14_linux_x64.tgz
                elif node --version | grep v12 > /dev/null ; then
                    echo "Node 12 detected."
                    curl -Lo ~/juice-shop.tar.gz https://github.com/juice-shop/juice-shop/releases/download/v13.3.0/juice-shop-13.3.0_node12_linux_x64.tgz
                else
                    echo -e "\nUnsupported NodeJS version. Exiting.\n"
                    return
                fi
            fi
            echo -e "\nLoading ...\n"
            tar -xzf ~/juice-shop.tar.gz -C ~/
            mv ~/juice-shop_13.3.0 $JUICE_DIR
            mv ~/juice-shop_14.0.1 $JUICE_DIR
            echo -e "\nJuice Shop files installed.\n\n\n"
        fi

        cd $JUICE_DIR
        echo -e "Getting ready to sell some Juice!\n\n\n"
        npm start
    )

}

export -f express
export -f eslint
export -f vnu
export -f sql_stop
export -f sql_start
export -f sql_reset
export -f juice_shop
