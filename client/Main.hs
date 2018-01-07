module Main where

import Client
import System.Environment (getArgs)

main :: IO ()
main = do
  [serverAddr, clientHost, port, chatName] <- getArgs
  putStrLn "Chat client running ..."
  launchChatClient serverAddr clientHost (read port) chatName
