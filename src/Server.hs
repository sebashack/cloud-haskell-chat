{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}


module Server where


import GHC.Generics
import Data.Binary
import Data.Typeable.Internal
import Control.Monad.IO.Class (liftIO)
import Control.Monad (void, forever)
import Control.Monad.Fix (fix)
import Network.Transport.TCP (createTransport, defaultTCPParameters)
-- import Control.Distributed.Process.Backend.SimpleLocalnet (initializeBackend, Backend(..))
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
                                   , expect
                                   , Process
                                   , ProcessId(..)
                                   , SendPort
                                   , ReceivePort )
import Control.Distributed.Process.ManagedProcess.Server (replyChan, continue_)
import Control.Distributed.Process.Extras.Time (Delay(..))
import Control.Distributed.Process.Node ( initRemoteTable
                                        , runProcess
                                        , forkProcess
                                        , newLocalNode
                                        , LocalNode )
import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (liftIO)


newtype Message = Message { unMessage :: String }
  deriving (Generic, Typeable, Show)

instance Binary Message

logMessage :: Message -> Process ()
logMessage = say . unMessage

-- backend :: IO Backend
-- backend = do
--   let host = "127.0.0.1"
--       port = "3000"
--   initializeBackend host port initRemoteTable

server :: IO ()
server = do
  Right transport <- createTransport "127.0.0.1" "8088" defaultTCPParameters
  node <- newLocalNode transport initRemoteTable
  forever $ runProcess node $ do
    self <- getSelfPid
    pId <- launchChatServer
    register "chat-1" self
    msg <- expect :: Process Message
    say $ unMessage msg

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
  in say "Process listening" >> spawnLocal (serve () (statelessInit Infinity) server)
