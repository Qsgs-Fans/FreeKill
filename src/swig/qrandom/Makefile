# Compiler settings
CXX = g++
CXXFLAGS = -std=c++17 -fPIC -shared -Wall -Wextra
LDFLAGS = -llua5.4 -lQt6Core

# Paths
LUA_INC = /usr/include/lua5.4
QT_INC = $(shell pkg-config --cflags Qt6Core)
QT_LIB = $(shell pkg-config --libs Qt6Core)

# Target
TARGET = freekill-qrandomgen.so
SRCS = freekill-qrandomgen.cpp
OBJS = $(SRCS:.cpp=.o)

# Install paths
INSTALL_DIR = /usr/local/lib/lua/5.4

# Build rule
all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS) $(QT_LIB)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@ -I$(LUA_INC) $(QT_INC)

# Install rule
install: $(TARGET)
	mkdir -p $(INSTALL_DIR)
	strip $(TARGET)
	cp $(TARGET) $(INSTALL_DIR)/$(TARGET)
	ldconfig # Update library cache (optional)

# Clean rule
clean:
	rm -f $(OBJS) $(TARGET)

# Phony targets
.PHONY: all install clean
