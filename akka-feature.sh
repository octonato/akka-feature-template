
function akka.new.feature {

    if [ $1 ]; then

        # create feature worktree
        cd ~/Sources/akka/feature/template
        git.worktree -p $1
        ./set-feature.sh $1


        DIR=$(pwd)
        echo "Feature directory is $DIR"
        (
            echo
            echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
            echo "Creating sdk worktree at ${DIR}/$1-sdk"
            cd ~/Sources/akka/sdk/main
            git.worktree -p ${DIR}/$1-sdk
            echo "-----------------------------------------------"
            echo
        )

        (
            echo
            echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
            echo "Creating runtime worktree at ${DIR}/$1-runtime"
            cd ~/Sources/akka/runtime/main
            git.worktree -p ${DIR}/$1-runtime
            echo "-----------------------------------------------"
            echo
        )

        # the root project requires samples to be available at the root
        echo "-----------------------------------------------"
        echo "Creating symlink for samples at ${1}-sdk/samples"
        ln -s $1-sdk/samples samples
        echo "-----------------------------------------------"
        echo

        git add .
        git commit -m "feat: initialize '$1'"

        echo
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        echo "Created feature worktree at $DIR"
        echo "  SDK worktree at ${DIR}/$1-sdk"
        echo "  Runtime worktree at ${DIR}/$1-runtime"
        echo "Done"
    fi
}

function akka.close.feature {

    if [ $1 ]; then
        (
            DIR=~/Sources/akka/feature/$1


            echo "Deleting feature branch '$1'"
            echo "  SDK worktree at ${DIR}/$1-sdk"
            echo "  Runtime worktree at ${DIR}/$1-runtime"
            echo "  Feature worktree at ${DIR}"
            echo "-----------------------------------------------"
            echo


            echo
            echo "-----------------------------------------------"
            echo "Deleting SDK worktree at ${DIR}/$1-sdk"
            git.delete.branch ${DIR}/$1-sdk
            echo
            echo "-----------------------------------------------"
            echo "Deleting Runtime worktree at ${DIR}/$1-runtime"
            git.delete.branch ${DIR}/$1-runtime
            echo
            echo "-----------------------------------------------"
            echo "Finally delete feature worktree ${DIR}"
            git.delete.branch ${DIR}
            echo "-----------------------------------------------"
        )
    fi
}
