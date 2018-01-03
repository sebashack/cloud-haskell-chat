{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}
{-# LANGUAGE RecordWildCards    #-}

module Server where

import Network.Transport.TCP (createTransport, defaultTCPParameters)
import Control.Distributed.Process.ManagedProcess ( serve
                                                  , defaultProcess
                                                  , handleRpcChan
                                                  , handleCast
                                                  , InitResult(..)
                                                  , UnhandledMessagePolicy(..)
                                                  , ChannelHandler
                                                  , ActionHandler
                                                  , CastHandler
                                                  , ProcessDefinition(..) )
import Control.Distributed.Process ( say
                                   , spawnLocal
                                   , register
                                   , monitorPort
                                   , receiveWait
                                   , matchIf
                                   , getSelfPid
                                   , Process
                                   , ProcessId(..)
                                   , ProcessMonitorNotification(..) )
import Control.Distributed.Process.ManagedProcess.Server (replyChan, continue)
import Control.Distributed.Process.ManagedProcess.Client (cast)
import Control.Distributed.Process.Extras.Time (Delay(..))
import Control.Distributed.Process.Node ( initRemoteTable
                                        , runProcess
                                        , newLocalNode )
import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (liftIO)
import Control.Monad (forever, forM_, void)
import qualified Data.Map as M (insert, empty, member, delete)
import Types

serveChatRoom :: ChatName -> IO ()
serveChatRoom name = do
  mt <- createTransport "127.0.0.1" "8088" defaultTCPParameters
  case mt of
    Right transport -> do
      node <- newLocalNode transport initRemoteTable
      runProcess node $ do
        pId <- launchChatServer
        say $ "Process launched: " ++ show pId
        register name pId
        liftIO $ forever $ threadDelay 500000
    Left err -> putStrLn (show err)

broadcastMessage :: ClientPortMap -> ChatMessage -> Process ()
broadcastMessage clientPorts msg =
  forM_ clientPorts (flip replyChan msg)

-- Server Code
messageHandler :: CastHandler ClientPortMap ChatMessage
messageHandler = handler
  where
    handler :: ActionHandler ClientPortMap ChatMessage
    handler clients msg = do
      broadcastMessage clients msg
      continue clients

joinChatHandler :: ChannelHandler ClientPortMap JoinChatMessage ChatMessage
joinChatHandler sp = handler
  where
    handler :: ActionHandler ClientPortMap JoinChatMessage
    handler clients JoinChatMessage{..} =
      if clientName `M.member` clients
        then replyChan sp (ChatMessage Server "Nickname already in use ... ") >> continue clients
        else do
          clientMonitor <- monitorPort sp
          serverPid <- getSelfPid
          void $ spawnLocal $ forever $ receiveWait [
            matchIf (\(ProcessMonitorNotification monitorRef _ _) -> monitorRef == clientMonitor)
                    (\ProcessMonitorNotification{} -> cast serverPid (DeleteClientMessage clientName))
            ]
          let clients' = M.insert clientName sp clients
          broadcastMessage clients $ ChatMessage Server (clientName ++ " has joined the chat ...")
          continue clients'

removeFromChatHandler :: CastHandler ClientPortMap DeleteClientMessage
removeFromChatHandler = handler
  where
    handler :: ActionHandler ClientPortMap DeleteClientMessage
    handler clients (DeleteClientMessage nickName) = do
      let clients' = M.delete nickName clients
      broadcastMessage clients' (ChatMessage Server $ nickName ++ " has left chat ... ")
      continue clients'

launchChatServer :: Process ProcessId
launchChatServer =
  let server = defaultProcess {
          apiHandlers =  [ handleRpcChan joinChatHandler
                         , handleCast messageHandler
                         , handleCast removeFromChatHandler
                         ]
        , unhandledMessagePolicy = Log
        }
  in spawnLocal $ serve () (const (return $ InitOk M.empty Infinity)) server
