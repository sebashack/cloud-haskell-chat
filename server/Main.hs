module Main where

import Server
import System.Environment (getArgs)

main :: IO ()
main = do
  [serverAddr, port, chatName] <- getArgs
  putStrLn "Chat server running ..."
  serveChatRoom serverAddr (read port) chatName
