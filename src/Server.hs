module Server where

import Control.Monad.IO.Class (liftIO)
import Control.Monad (void, forever)
import Control.Monad.Fix (fix)
import Control.Distributed.Process.Backend.SimpleLocalnet (initializeBackend, Backend(..))
import Control.Distributed.Process.ManagedProcess ( serve
                                                  , statelessInit
                                                  , statelessProcess
                                                  , handleCall_
                                                  , handleRpcChan_
                                                  , InitResult(..)
                                                  , UnhandledMessagePolicy(..)
                                                  , StatelessChannelHandler
                                                  , StatelessHandler
                                                  , Action
                                                  , ProcessDefinition(..) )
import Control.Distributed.Process ( getSelfPid
                                   , send
                                   , say
                                   , expect
                                   , newChan
                                   , spawnLocal
                                   , matchChan
                                   , receiveWait
                                   , register
                                   , Process
                                   , ProcessId(..)
                                   , SendPort
                                   , ReceivePort )
import Control.Distributed.Process.ManagedProcess.Server (replyChan, continue_)
import Control.Distributed.Process.Extras.Time (Delay(..))
import Control.Distributed.Process.Node ( initRemoteTable
                                        , runProcess
                                        , LocalNode )
import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (liftIO)


type Message = String

logMessage :: Message -> Process ()
logMessage = say

backend :: IO (Backend, LocalNode)
backend = do
  let host = "127.0.0.1"
      port = "8882"
  bk <- initializeBackend host port initRemoteTable
  node <- newLocalNode bk
  return (bk, node)

server :: IO ()
server = do
  (_, node) <- backend
  runProcess node $  do
    pId <- launchChatServer
    register "chat-1" pId
    liftIO $ threadDelay 20000000000

-- Server Code
messageHandler :: StatelessChannelHandler () Message Message
messageHandler sp = statelessHandler
  where
    statelessHandler :: StatelessHandler () Message
    statelessHandler msg a@() = replyChan sp msg >> continue_ a

launchChatServer :: Process ProcessId
launchChatServer =
  let server = statelessProcess {
          apiHandlers =  [ handleRpcChan_ messageHandler ]
        , unhandledMessagePolicy = Drop
        }
  in spawnLocal $ serve () (statelessInit Infinity) server
