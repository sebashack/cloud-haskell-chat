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
  mt <- createTransport "127.0.0.1" "8088" defaultTCPParameters
  case mt of
    Right transport -> do
      node <- newLocalNode transport initRemoteTable
      runProcess node $ do
        pId <- launchChatServer
        say $ "Process launched: " ++ show pId
        register "chat-1" pId
        liftIO $ forever $ threadDelay 500000
    Left err -> putStrLn (show err)

broadcastMessage :: [SendPort ChatMessage] -> ChatMessage -> Process ()
broadcastMessage clientPorts msg = forM_ clientPorts $ flip replyChan msg

-- Server Code
messageHandler_ :: StatelessChannelHandler () ChatMessage ChatMessage
messageHandler_ sp = statelessHandler
  where
    statelessHandler :: StatelessHandler () ChatMessage
    statelessHandler msg a@() = replyChan sp msg >> continue_ a

messageHandler :: CastHandler [SendPort ChatMessage] ChatMessage
messageHandler = handler
  where
    handler :: ActionHandler [SendPort ChatMessage] ChatMessage
    handler clients msg = do
      broadcastMessage clients msg
      continue clients

joinChatHandler :: ChannelHandler [SendPort ChatMessage] JoinChatMessage ChatMessage
joinChatHandler sp = handler
  where
    handler :: ActionHandler [SendPort ChatMessage] JoinChatMessage
    handler clients JoinChatMessage{..} = do
      let clients' = sp : clients
      broadcastMessage clients $ ChatMessage Server (clientName ++ " has joined the chat ...")
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
