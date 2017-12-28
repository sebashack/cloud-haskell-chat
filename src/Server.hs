{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}


module Server where

import Control.Monad.IO.Class (liftIO)
import Control.Monad (void, forever)
import Control.Monad.Fix (fix)
import Network.Transport.TCP (createTransport, defaultTCPParameters)
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
import Control.Distributed.Process.ManagedProcess.Server (replyChan, handleCall_, continue_)
import Control.Distributed.Process.Extras.Time (Delay(..))
import Control.Distributed.Process.Node ( initRemoteTable
                                        , runProcess
                                        , forkProcess
                                        , newLocalNode
                                        , LocalNode )
import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (liftIO)
import Types

server :: IO ()
server = do
  Right transport <- createTransport "127.0.0.1" "8088" defaultTCPParameters
  node <- newLocalNode transport initRemoteTable
  forever $ runProcess node $ do
    pId <- launchChatServer
    say $ "Process launched: " ++ show pId
    register "chat-1" pId
    liftIO (threadDelay $ 1000 * 1000000)

-- Server Code
messageHandler :: StatelessChannelHandler () Message Message
messageHandler sp = statelessHandler
  where
    statelessHandler :: StatelessHandler () Message
    statelessHandler msg a@() = replyChan sp msg >> continue_ a

launchChatServer :: Process ProcessId
launchChatServer =
  let server = statelessProcess {
          apiHandlers =  [ handleRpcChan_ messageHandler
                         , handleCall_ (\(Message msg) -> say msg) ]
        , unhandledMessagePolicy = Drop
        }
  in spawnLocal (serve () (statelessInit Infinity) server)
