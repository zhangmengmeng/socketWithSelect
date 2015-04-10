//
//  main.m
//  SocketClient
//
//  Created by dorayo on 14-9-13.
//  Copyright (c) 2014年 dorayo.com. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>

#define SERVER_PORT 8888
#define SERVER_IP "127.0.0.1"
#define BUFFER_SIZE 1024
#define QUIT_CMD ".quit"

int main (int argc, const char * argv[])
{
    char recv_msg[BUFFER_SIZE];
    char input_msg[BUFFER_SIZE];
    
    // 服务器地址
    struct sockaddr_in server_addr = {0};
    server_addr.sin_len = sizeof(struct sockaddr_in);
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(SERVER_PORT);
    server_addr.sin_addr.s_addr = inet_addr(SERVER_IP);
    
    int server_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (server_sock == -1) {
        perror("socket error");
        exit(1);
    }
    
    if (connect(server_sock, (struct sockaddr *)&server_addr, sizeof(struct sockaddr_in))==0) {
        fd_set client_fd_set;
        struct timeval tv;
        tv.tv_sec = 20;
        tv.tv_usec = 0;
        
        
        while (1) {
            FD_ZERO(&client_fd_set);
            FD_SET(STDIN_FILENO, &client_fd_set);
            FD_SET(server_sock, &client_fd_set);
            
            int ret = select(server_sock + 1, &client_fd_set, NULL, NULL, &tv);
            
            // ret为状态发生变化的文件描述符的个数
            if (ret < 0 ) {
                perror("select error\n");
                continue;
            } else if (ret ==0){
                fprintf(stderr, "select timeout...\n");
                continue;
            } else {
                
                if (FD_ISSET(STDIN_FILENO, &client_fd_set)) {
                    bzero(input_msg, BUFFER_SIZE);
                    fgets(input_msg, BUFFER_SIZE, stdin);
                    //输入 ".quit" 则退出服务器
                    if (strncmp(input_msg, QUIT_CMD, strlen(QUIT_CMD)) == 0) {
                        close(server_sock);
                        exit(0);
                    }
                    
                    if (send(server_sock, input_msg, BUFFER_SIZE, 0) == -1) {
                        perror("发送消息出错!\n");
                    }
                }
                
                if (FD_ISSET(server_sock, &client_fd_set)) {
                    bzero(recv_msg, BUFFER_SIZE);
                    long byte_num = recv(server_sock,recv_msg,BUFFER_SIZE,0);
                    if (byte_num > 0) {
                        if (byte_num > BUFFER_SIZE) {
                            byte_num = BUFFER_SIZE;
                        }
                        recv_msg[byte_num] = '\0';
                        printf("服务器:%s\n",recv_msg);
                    }else if(byte_num < 0){
                        printf("接收消息出错!\n");
                    }else{
                        printf("服务器端退出!\n");
                        close(server_sock);
                        exit(0);
                    }
                }
            }
        }
        
    }
    
    return 0;
}