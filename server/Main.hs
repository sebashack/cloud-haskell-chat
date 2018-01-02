module Main where

import Server
import System.Environment (getArgs)

main :: IO ()
main = do
  [chatName] <- getArgs
  putStrLn "Chat server running ..."
  serveChatRoom chatName
