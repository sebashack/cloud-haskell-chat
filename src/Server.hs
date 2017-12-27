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
  let host = "127.0.0.1"
      port = "3000"
  Right transport <- createTransport "127.0.0.1" "8080" defaultTCPParameters
  node <- newLocalNode transport initRemoteTable
  forever $ runProcess node $ do
    msg <- expect :: Process Message
    pId <- launchChatServer
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
  in spawnLocal $ serve () (statelessInit Infinity) server
