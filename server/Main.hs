module Main where

import Server

main :: IO ()
main = do
  putStrLn "Starting chat server ... "
  server
