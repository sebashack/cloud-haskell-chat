module Client where

import Control.Distributed.Process.ManagedProcess.Client (callChan)
import Control.Distributed.Process (whereisRemoteAsync)
import Control.Distributed.Process.Backend.SimpleLocalnet (initializeBackend, Backend(..))
import Control.Distributed.Process ( expect
                                   , say
                                   , receiveWait
                                   , spawnLocal
                                   , matchChan
                                   , Process
                                   , ProcessId
                                   , ReceivePort
                                   , WhereIsReply(..) )
import Control.Distributed.Process.Node ( initRemoteTable
                                        , runProcess
                                        , LocalNode)
import Control.Monad.IO.Class (liftIO)
import Control.Monad (void, forever)

-- Client code
sendMsg :: ProcessId -> String -> Process (ReceivePort String)
sendMsg sid msg = callChan sid msg

searchChatServer :: Backend -> Process (Maybe ProcessId)
searchChatServer backend = do
  peers <- liftIO $ findPeers backend $ 1000000
  search peers
  where
    search [] = return Nothing
    search (peer : ps) = do
      whereisRemoteAsync peer "chat-1"
      WhereIsReply _ remoteWhereIs <- expect
      case remoteWhereIs of
        Just chatServerPid -> return (Just chatServerPid)
        Nothing -> search ps

logMsgBack :: String -> Process ()
logMsgBack result =
  say $ "result: " ++ show result

launchChatClient :: (Backend, LocalNode) -> IO ()
launchChatClient (serverBk, _) = do
  let host = "127.0.0.1"
      port = "7882"
  clientBk <- initializeBackend host port initRemoteTable
  node <- newLocalNode clientBk
  runProcess node $ do
    mPid <- searchChatServer serverBk
    case mPid of
      Just pId -> do
        say "Server found !!"
        rp <- sendMsg pId "Hello server"
        void $ spawnLocal $ forever $
          receiveWait [matchChan rp logMsgBack]
      Nothing -> say "No chat server found !!"
