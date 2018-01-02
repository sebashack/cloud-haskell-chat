module Main where

import Client
import System.Environment (getArgs)

main :: IO ()
main = do
  [clientAddr, chatName] <- getArgs
  putStrLn "Chat client running ..."
  launchChatClient clientAddr chatName
