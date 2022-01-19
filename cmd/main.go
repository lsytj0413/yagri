package main

import (
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"

	"github.com/lsytj0413/yagri/pkg"
)

var errParseWait = errors.New("ParseWait")

func parseCommand(buf string) error {
	cmds := strings.Split(buf, "\r\n")
	if len(cmds) == 0 {
		return errParseWait
	}

	bulklen, err := strconv.ParseInt(cmds[0][1:], 10, 64)
	if err != nil {
		return err
	}
	fmt.Println("Receieve bulklen: ", bulklen)

	if int64(len(cmds)) < 2*bulklen+1 {
		return errParseWait
	}

	argv := []string{}
	cmds = cmds[1:]
	for i := 0; i < int(bulklen); i++ {
		if cmds[i*2][0] != '$' {
			return errors.New("Unexpected char")
		}

		cmdlen, err := strconv.ParseInt(cmds[i*2][1:], 10, 64)
		if err != nil {
			return err
		}

		cmdv := cmds[i*2+1]
		if int64(len(cmdv)) < cmdlen {
			return errParseWait
		}

		argv = append(argv, cmdv)
	}

	fmt.Println(argv)
	return nil
}

func process(conn net.Conn) {
	client := conn.RemoteAddr().String()
	defer conn.Close()

	fmt.Printf("Start to process %s\n", client)
	for {
		buf := make([]byte, 1024)
		n, err := conn.Read(buf)
		if err != nil {
			fmt.Printf("Read message from %s failed, %v\n", client, err)
			return
		}

		cmd := string(buf[:n])
		fmt.Printf("Read %s from %s\n", string(cmd), client)

		if cmd[0] != '*' {
			fmt.Printf("The first byte must be *, received %s, client %s\n", string(cmd[0]), client)
			return
		}

		// TODO: 有两种协议
		//  1. inline: https://redis.io/topics/protocol#inline-commands，源码见 processInlineBuffer
		//  2. multibulk: 源码见 processMultibulkBuffer
		//  3. 解析完 command 后，执行的源码见 processCommandAndResetClient
		err = parseCommand(cmd)
		if err != nil {
			if err != errParseWait {
				fmt.Printf("Parse command failed: %v", err)
				return
			}

			fmt.Printf("wait for next buffer to parse")
			continue
		}

		// TODO: the full command has received
		conn.Write([]byte("*7\r\n$7\r\nCOMMAND\r\n:0\r\n*1\r\n+readonly\r\n:0\r\n:0\r\n:0\r\n*1\r\n+@read\r\n"))
	}
}

func main() {
	pkg.Print()
	fmt.Println("yagri main")

	listen, err := net.Listen("tcp", "127.0.0.1:6380")
	if err != nil {
		panic(err)
	}

	for {
		conn, err := listen.Accept()
		if err != nil {
			panic(err)
		}

		go process(conn)
	}
}
