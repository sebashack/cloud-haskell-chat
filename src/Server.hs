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
                                   , Process
                                   , ProcessId(..)
                                   , SendPort
                                   , ReceivePort )
import Control.Distributed.Process.ManagedProcess.Server (replyChan, continue_)
import Control.Distributed.Process.Extras.Time (Delay(..))
import Control.Distributed.Process.Node ( initRemoteTable
                                        , runProcess )
import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (liftIO)


type Message = String

logMessage :: Message -> Process ()
logMessage = say

server :: IO ()
server = do
  let host = "127.0.0.1"
      port = "4242"
  backend <- initializeBackend host port initRemoteTable
  node <- newLocalNode backend
  void $ runProcess node $ do
    say "Starting new connection ... "
    pId <- launchChatServer
    liftIO $ threadDelay 2000000

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
