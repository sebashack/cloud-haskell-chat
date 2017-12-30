{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}
{-# LANGUAGE RecordWildCards    #-}

module Server where

import Control.Monad.IO.Class (liftIO)
import Control.Monad (void, forever)
import Control.Monad.Fix (fix)
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import Control.Distributed.Process.ManagedProcess ( serve
                                                  , statelessInit
                                                  , statelessProcess
                                                  , defaultProcess
                                                  , handleCall_
                                                  , handleRpcChan_
                                                  , handleRpcChan
                                                  , handleCast
                                                  , InitResult(..)
                                                  , UnhandledMessagePolicy(..)
                                                  , ChannelHandler
                                                  , ActionHandler
                                                  , CastHandler
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
import Control.Distributed.Process.ManagedProcess.Server (replyChan, handleCall_, continue_, continue)
import Control.Distributed.Process.Extras.Time (Delay(..))
import Control.Distributed.Process.Node ( initRemoteTable
                                        , runProcess
                                        , forkProcess
                                        , newLocalNode
                                        , LocalNode )
import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (liftIO)
import Control.Monad (forM_)
import Types

server :: IO ()
server = do
  Right transport <- createTransport "127.0.0.1" "8088" defaultTCPParameters
  node <- newLocalNode transport initRemoteTable
  runProcess node $ do
    pId <- launchChatServer
    say $ "Process launched: " ++ show pId
    register "chat-1" pId
    liftIO (threadDelay $ 1000 * 1000000)

broadcastMessage :: [SendPort Message] -> Message -> Process ()
broadcastMessage clientPorts msg = forM_ clientPorts $ flip replyChan msg

-- Server Code
messageHandler_ :: StatelessChannelHandler () Message Message
messageHandler_ sp = statelessHandler
  where
    statelessHandler :: StatelessHandler () Message
    statelessHandler msg a@() = replyChan sp msg >> continue_ a

messageHandler :: CastHandler [SendPort Message] Message
messageHandler = handler
  where
    handler :: ActionHandler [SendPort Message] Message
    handler clients msg = do
      broadcastMessage clients msg
      continue clients

joinChatHandler :: ChannelHandler [SendPort Message] JoinChatMessage Message
joinChatHandler sp = handler
  where
    handler :: ActionHandler [SendPort Message] JoinChatMessage
    handler clients JoinChatMessage{..} = do
      let clients' = sp : clients
      broadcastMessage clients' (Message $ clientName ++ " has joined the chat ...")
      continue clients'

launchChatServer :: Process ProcessId
launchChatServer =
  let server = defaultProcess {
          apiHandlers =  [ handleRpcChan joinChatHandler
                         , handleCast messageHandler
                         ]
        , unhandledMessagePolicy = Drop
        }
  in spawnLocal $ serve () (const (return $ InitOk [] Infinity)) server
