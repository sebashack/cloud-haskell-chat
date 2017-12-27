{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}


module Client where

import Control.Distributed.Process.ManagedProcess.Client (callTimeout, callChan)
import Control.Distributed.Process (whereisRemoteAsync, NodeId(..))
import Control.Distributed.Process.Backend.SimpleLocalnet (initializeBackend, Backend)
import qualified Control.Distributed.Process.Backend.SimpleLocalnet as B (Backend(..))
import Control.Distributed.Process ( expect
                                   , expectTimeout
                                   , say
                                   , send
                                   , receiveWait
                                   , spawnLocal
                                   , matchChan
                                   , Process
                                   , ProcessId
                                   , ReceivePort
                                   , WhereIsReply(..) )
import Control.Distributed.Process.Node ( initRemoteTable
                                        , runProcess
                                        , newLocalNode
                                        , LocalNode)
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import Network.Transport     (EndPointAddress(..))
import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (liftIO)
import Control.Monad (void, forever)
import Server (Message(..))
import Control.Distributed.Process.Extras.Time (milliSeconds)
import qualified Data.ByteString.Char8 as BS (pack)

-- Client code
sendMsg :: ProcessId -> String -> Process (ReceivePort String)
sendMsg sid msg = callChan sid msg

searchChatServer :: String -> Process ProcessId
searchChatServer serverAddr = do
  say "searching ..."
  let addr = EndPointAddress (BS.pack serverAddr)
      srvId = NodeId addr
  whereisRemoteAsync srvId "chat-1"
  reply <- expectTimeout 1000
  case reply of
    Just (WhereIsReply _ msid) -> case msid of
      Just sid -> return sid
      Nothing  -> searchChatServer serverAddr
    Nothing -> searchChatServer serverAddr

logMsgBack :: String -> Process ()
logMsgBack result =
  say $ "result: " ++ show result

launchChatClient :: IO ()
launchChatClient = do
  let host = "127.0.0.2"
      port = "8080"
  Right transport <- createTransport "127.0.0.2" "8080" defaultTCPParameters
  node <- newLocalNode transport initRemoteTable
  runProcess node $ do
    pId <- searchChatServer "127.0.0.1"
    say "Server found !!"
    res <- callTimeout pId (Message "Hello server") (milliSeconds 1000) :: Process (Maybe Message)
    return ()
