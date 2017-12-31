{-# LANGUAGE RecordWildCards    #-}

module Logger where

import Control.Distributed.Process ( receiveWait
                                   , match
                                   , register
                                   , nsend
                                   , Process )
import Control.Monad.IO.Class (liftIO)
import System.IO (hPutStrLn, stdout)
import Control.Distributed.Process.Node (runProcess, forkProcess, LocalNode)
import Types

chatMessageToStr :: ChatMessage -> String
chatMessageToStr ChatMessage{..} =
  case from of
    Server ->  message
    Client sender-> sender ++ ": " ++ message

chatLogger :: Process ()
chatLogger = receiveWait
  [ match $ \chatMessage -> do
      liftIO . hPutStrLn stdout $ chatMessageToStr chatMessage
      chatLogger
  , match $ \str -> do
      let output :: String
          output = str
      liftIO . hPutStrLn stdout $ output
      chatLogger
  ]

runChatLogger :: LocalNode -> IO ()
runChatLogger node = do
  logger <- forkProcess node chatLogger
  runProcess node $ register "chatLogger" logger

logChatMessage :: ChatMessage -> Process ()
logChatMessage = nsend "chatLogger"

logStr :: String -> Process ()
logStr = nsend "chatLogger"
