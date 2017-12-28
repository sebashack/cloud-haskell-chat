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
                                   , receiveChan
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
  Right transport <- createTransport "127.0.0.2" "8088" defaultTCPParameters
  node <- newLocalNode transport initRemoteTable
  runProcess node $ do
    pId <- searchChatServer "127.0.0.1:8088:0"
    say $ "Server found: " ++ show pId
    rp <- callChan pId (Message "Hello server") :: Process (ReceivePort Message)
    (Message msg) <- receiveChan rp
    say $ "Message sent back: " ++ msg
    liftIO $ (threadDelay $ 2000000)
