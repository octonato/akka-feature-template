
if [ $1 ]; then

    # create feature worktree
    cd ~/Sources/akka/feature/template
    git.worktree -p $1
    ./set-feature.sh $1


    printf '%s\n' "/$1-sdk/" "/$1-runtime/" >> .git/info/exclude
    git add .
    git commit -m "feat: initialize '$1'"

    DIR=$(pwd)
    echo "Feature directory is $DIR"
    (
        echo "Creating sdk worktree at ${DIR}/$1-sdk"
        cd ~/Sources/akka/sdk/main
        git.worktree -p ${DIR}/$1-sdk
    )
    (
        echo "Creating runtime worktree at ${DIR}/$1-runtime"
        cd ~/Sources/akka/runtime/main
        git.worktree -p l${DIR}/$1-runtime
    )
fi
