module Server where

import Control.Monad.IO.Class (liftIO)
import Control.Monad (void, forever)
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import Control.Distributed.Process (getSelfPid, send)
import Control.Distributed.Process.Node ( newLocalNode
                                        , initRemoteTable
                                        , runProcess )

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
        self <- getSelfPid
        send self "hello"

-- selfMessage :: RemoteTable -> Transport -> IO ()
-- selfMessage tbl transport = do
--   node <- newLocalNode transport tbl
--   void $ runProcess node $ do
--     self <- getSelfPid
--     send self "hello"
--     hello <- expect :: Process String
--     liftIO $ putStrLn hello
--   return ()
