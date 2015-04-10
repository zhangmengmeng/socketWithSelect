//
//  main.m
//  SocketServer
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

#define BACKLOG 5           //完成三次握手但没有accept的队列的长度
#define CONCURRENT_MAX 8    //应用层同时可以处理的连接
#define SERVER_PORT 8888
#define SERVER_IP "127.0.0.1"
#define BUFFER_SIZE 1024
#define QUIT_CMD ".quit"



#define SET_MAX_FD(fd) {if (max_fd < (fd)) max_fd = (fd);}

int client_fds[CONCURRENT_MAX];


int main (int argc, const char * argv[])
{
    char input_msg[BUFFER_SIZE];
    char recv_msg[BUFFER_SIZE];

    // 服务器地址
    struct sockaddr_in server_addr = {0};
    server_addr.sin_len = sizeof(struct sockaddr_in);
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(SERVER_PORT);
    server_addr.sin_addr.s_addr = inet_addr(SERVER_IP);
   
    // 创建socket
    int server_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (server_sock == -1) {
        perror("socket error");
        exit(1);
    }
    // 绑定socket
    int bind_result = bind(server_sock, (struct sockaddr *)&server_addr, sizeof(server_addr));
    if (bind_result == -1) {
        perror("bind error");
        close(server_sock);
        exit(1);
    }
    
    // listen
    if (listen(server_sock, BACKLOG) == -1) {
        perror("listen error");
        close(server_sock);        
        exit(1);
    }
    
    //fd_set
    fd_set server_fd_set;
    int max_fd = -1;
    struct timeval tv;
    tv.tv_sec = 20;
    tv.tv_usec = 0;
    
    while (1) {
        FD_ZERO(&server_fd_set);
       
        // 置位标准输入描述符
        FD_SET(STDIN_FILENO, &server_fd_set);
        SET_MAX_FD(STDIN_FILENO)
        
        // 置位server_sock (这是个半相关socket)
        FD_SET(server_sock, &server_fd_set);
        SET_MAX_FD(server_sock)
        
        //客户端socket (这是全相关socket)
        for (int i = 0; i < CONCURRENT_MAX; i++) {
            if (client_fds[i] != 0) {
                FD_SET(client_fds[i], &server_fd_set);
                SET_MAX_FD(client_fds[i])
            }
        }
        
        int ret = select(max_fd+1, &server_fd_set, NULL, NULL, &tv);
        
        // ret为状态发生变化的文件描述符的个数
        if (ret < 0) {
            perror("select error\n");
            continue;
        } else if (ret == 0){
            fprintf(stderr, "select timeout...\n");
            continue;
        } else {
            if (FD_ISSET(STDIN_FILENO, &server_fd_set)) {
                // 当标准输入描述符可读时，进行如下处理
                bzero(input_msg, BUFFER_SIZE);
                fgets(input_msg, BUFFER_SIZE, stdin);
                
                //输入 ".quit" 则退出服务器
                if (strncmp(input_msg, QUIT_CMD, strlen(QUIT_CMD)) == 0) {
                    close(server_sock);
                    exit(0);
                }

                for (int i = 0; i < CONCURRENT_MAX; i++) {
                    if (client_fds[i] != 0) {
                        send(client_fds[i], input_msg, BUFFER_SIZE, 0);
                    }
                }
            }
            
            if (FD_ISSET(server_sock, &server_fd_set)) {
                // 当server_sock(半相关)可读时（意味着有新的连接请求），进行如下处理
                struct sockaddr_in client_address = {0};
                socklen_t address_len;
                int client_socket = accept(server_sock, (struct sockaddr *)&client_address, &address_len);
                if (client_socket > 0) {
                    int index = -1;
                    for (int i = 0; i < CONCURRENT_MAX; i++) {
                        if (client_fds[i] == 0) {
                            index = i;
                            client_fds[i] = client_socket;
                            break;
                        }
                    }

                    if (index >= 0) {
                        printf("新客户端(%d)加入成功 %s:%d \n",index,inet_ntoa(client_address.sin_addr),ntohs(client_address.sin_port));
                    } else {
                        bzero(input_msg, BUFFER_SIZE);
                        strcpy(input_msg, "服务器加入的客户端数达到最大值,无法加入!\n");
                        send(client_socket, input_msg, BUFFER_SIZE, 0);
                        printf("客户端连接数达到最大值，新客户端加入失败 %s:%d \n",inet_ntoa(client_address.sin_addr),ntohs(client_address.sin_port));
                    }
                }
            }
            
            // 遍历client_fds(全相关)中的所有描述符，当其可读时（意味着收到了client的消息），进行如下处理
            for (int i = 0; i <CONCURRENT_MAX; i++) {
                if (client_fds[i] != 0) {
                    if (FD_ISSET(client_fds[i], &server_fd_set)) {
                        //处理某个客户端过来的消息
                        bzero(recv_msg, BUFFER_SIZE);
                        long byte_num = recv(client_fds[i],recv_msg,BUFFER_SIZE,0);
                        if (byte_num > 0) {
                            if (byte_num > BUFFER_SIZE) {
                                byte_num = BUFFER_SIZE;
                            }
                            recv_msg[byte_num] = '\0';
                            printf("客户端(%d):%s\n",i,recv_msg);
                        } else if (byte_num < 0){
                            printf("从客户端(%d)接收消息出错\n",i);
                        } else {
                            FD_CLR(client_fds[i], &server_fd_set);
                            client_fds[i] = 0;
                            printf("客户端(%d)退出了\n",i);
                        }
                    }
                }
            }
        }
    }
    return 0;
}
