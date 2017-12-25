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
                                   , Process
                                   , ProcessId
                                   , SendPort
                                   , ReceivePort )
import Control.Distributed.Process.ManagedProcess.Server (replyChan, continue_)
import Control.Distributed.Process.Extras.Time (Delay(..))
import Control.Distributed.Process.Node ( newLocalNode
                                        , initRemoteTable
                                        , runProcess )


type Message = String

logMessage :: Message -> Process ()
logMessage = say

server :: IO ()
server = do
  let host = "127.0.0.1"
      port = "4242"
  eTrans <- createTransport host port defaultTCPParameters
  case eTrans of
    Left err -> putStrLn "" >> print err
    Right ts -> do
      node <- newLocalNode ts initRemoteTable
      void $ runProcess node $ do
        say "Start new connection... "
        (sp, rp) <- newChan :: Process (SendPort String, ReceivePort String)

        void $ spawnLocal $ forever $
          receiveWait [matchChan rp logMessage]

-- Server Code
addHandler :: StatelessChannelHandler () Message Message
addHandler sp = statelessHandler
  where
    statelessHandler :: StatelessHandler () Message
    statelessHandler msg a@() = replyChan sp msg >> continue_ a

launchChatServer :: Process ProcessId
launchChatServer =
  let server = statelessProcess {
        apiHandlers =  [ handleRpcChan_ addHandler ]
        , unhandledMessagePolicy = Drop
        }
  in spawnLocal $ serve () (statelessInit Infinity) server >> return ()
