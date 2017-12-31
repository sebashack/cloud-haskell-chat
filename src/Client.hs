{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}
{-# LANGUAGE RecordWildCards    #-}

module Client where

import Control.Distributed.Process.ManagedProcess.Client (callChan, cast)
import Control.Distributed.Process ( expectTimeout
                                   , say
                                   , whereisRemoteAsync
                                   , spawnLocal
                                   , receiveChan
                                   , nsend
                                   , NodeId(..)
                                   , Process
                                   , ProcessId
                                   , ReceivePort
                                   , WhereIsReply(..) )
import Control.Distributed.Process.Node ( initRemoteTable
                                        , runProcess
                                        , newLocalNode )
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import Network.Transport     (EndPointAddress(..))
import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (liftIO)
import Control.Monad (void, forever)
import System.Environment    (getArgs)
import qualified Data.ByteString.Char8 as BS (pack)
import Types


-- Client code
sendMsg :: ProcessId -> String -> Process (ReceivePort String)
sendMsg sid msg = callChan sid msg

searchChatServer :: String -> Process ProcessId
searchChatServer serverAddr = do
  let addr = EndPointAddress (BS.pack serverAddr)
      srvId = NodeId addr
  whereisRemoteAsync srvId "chat-1"
  reply <- expectTimeout 1000
  case reply of
    Just (WhereIsReply _ msid) -> case msid of
      Just sid -> return sid
      Nothing  -> searchChatServer serverAddr
    Nothing -> searchChatServer serverAddr

logChatMessage :: ChatMessage -> Process ()
logChatMessage ChatMessage{..} =
  case from of
    Server ->  say message
    Client sender-> say $ sender ++ ": " ++ message

launchChatClient :: IO ()
launchChatClient = do
  [serverAddr] <- getArgs
  mt <- createTransport serverAddr "8088" defaultTCPParameters
  case mt of
    Left err -> putStrLn (show err)
    Right transport -> do
      node <- newLocalNode transport initRemoteTable
      runProcess node $ do
        serverPid <- searchChatServer "127.0.0.1:8088:0"
        say "Joining chat server ... "
        say "Please, provide your nickname ... "
        nickName <- liftIO getLine
        rp <- callChan serverPid (JoinChatMessage nickName) :: Process (ReceivePort ChatMessage)
        say "You have joined the chat ... "
        void $ spawnLocal $ forever $ do
          msg <- receiveChan rp
          logChatMessage msg
        forever $ do
          chatInput <- liftIO getLine
          cast serverPid (ChatMessage (Client nickName) chatInput)
          liftIO $ threadDelay 500000

-- 127.0.0.x
