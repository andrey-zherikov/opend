#ifndef LLVMDC_IR_IRLANDINGPADINFO_H
#define LLVMDC_IR_IRLANDINGPADINFO_H

#include "ir/ir.h"
#include "statement.h"

#include <deque>
#include <stack>

struct IRLandingPadInfo
{
    // default constructor for being able to store in a vector
    IRLandingPadInfo()
    : target(NULL), finallyBody(NULL), catchType(NULL)
    {}

    IRLandingPadInfo(Catch* catchstmt, llvm::BasicBlock* end);
    IRLandingPadInfo(Statement* finallystmt);

    // the target catch bb if this is a catch
    // or the target finally bb if this is a finally
    llvm::BasicBlock* target;

    // nonzero if this is a finally
    Statement* finallyBody;

    // nonzero if this is a catch
    ClassDeclaration* catchType;
};

struct IRLandingPad
{
    IRLandingPad() : catch_var(NULL) {}

    // builds a new landing pad according to given infos
    // and the ones on the stack. also stores it as invoke target
    void push(llvm::BasicBlock* inBB);

    void addCatch(Catch* catchstmt, llvm::BasicBlock* end);
    void addFinally(Statement* finallystmt);

    // pops the most recently constructed landing pad bb
    // and its infos
    void pop();

    // gets the current landing pad
    llvm::BasicBlock* get();

    // creates or gets storage for exception object
    LLValue* getExceptionStorage();

private:
    // constructs the landing pad from infos
    void constructLandingPad(llvm::BasicBlock* inBB);

    // information needed to create landing pads
    std::deque<IRLandingPadInfo> infos;
    std::deque<IRLandingPadInfo> unpushed_infos;

    // the number of infos we had before the push
    std::stack<size_t> nInfos;

    // the target for invokes
    std::stack<llvm::BasicBlock*> padBBs;

    // storage for the catch variable
    LLValue* catch_var;
};

#endif
