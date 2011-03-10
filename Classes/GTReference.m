//
//  GTReference.m
//  ObjectiveGitFramework
//
//  Created by Timothy Clem on 3/2/11.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "GTReference.h"
#import "GTRepository.h"
#import "GTLib.h"
#import "NSString+Git.h"
#import "NSError+Git.h"


@implementation GTReference

@synthesize ref;
@synthesize repo;
@synthesize type;

+ (id)referenceByLookingUpRef:(NSString *)refName inRepo:(GTRepository *)theRepo error:(NSError **)error {

	return [[[self alloc] initByLookingUpRef:refName inRepo:theRepo error:error] autorelease];
}

+ (id)referenceByCreatingRef:(NSString *)refName fromRef:(NSString *)target inRepo:(GTRepository *)theRepo error:(NSError **)error {
		
	return [[[self alloc] initByCreatingRef:refName fromRef:target inRepo:theRepo error:error] autorelease];
}

+ (id)referenceByResolvingRef:(GTReference *)symbolicRef error:(NSError **)error {
	
	return [[[self alloc] initByResolvingRef:symbolicRef error:error] autorelease];
}

- (id)initByLookingUpRef:(NSString *)refName inRepo:(GTRepository *)theRepo error:(NSError **)error {
	
	if(self = [super init]) {
		self.repo = theRepo;
		int gitError = git_reference_lookup(&ref, self.repo.repo, [NSString utf8StringForString:refName]);
		if(gitError != GIT_SUCCESS){
			if(error != NULL)
				*error = [NSError gitErrorForLookupRef:gitError];
			return nil;
		}
	}
	return self;
}

- (id)initByCreatingRef:(NSString *)refName fromRef:(NSString *)theTarget inRepo:(GTRepository *)theRepo error:(NSError **)error {
	
	if(self = [super init]) {
		
		git_oid oid;
		int gitError;
		
		self.repo = theRepo;
		if (git_oid_mkstr(&oid, [NSString utf8StringForString:theTarget]) == GIT_SUCCESS) {
			
			gitError = git_reference_create_oid(&ref, 
												self.repo.repo, 
												[NSString utf8StringForString:refName], 
												&oid);
		}
		else {
			
			gitError = git_reference_create_symbolic(&ref, 
													 self.repo.repo, 
													 [NSString utf8StringForString:refName], 
													 [NSString utf8StringForString:theTarget]);
		}
		
		if(gitError != GIT_SUCCESS){
			if(error != NULL)
				*error = [NSError gitErrorForCreateRef:gitError];
			return nil;
		}
	}
	return self;
}

- (id)initByResolvingRef:(GTReference *)symbolicRef error:(NSError **)error {
	
	if(self = [super init]) {
		
		int gitError = git_reference_resolve(&ref, symbolicRef.ref);
		if(gitError != GIT_SUCCESS) {
			if(error != NULL)
				*error = [NSError gitErrorForResloveRef:gitError];
			return nil;
		}
		self.repo = symbolicRef.repo;
	}
	return self;
}

- (NSString *)name {
	
	return [NSString stringForUTF8String:git_reference_name(self.ref)];
}
- (void)setName:(NSString *)newName error:(NSError **)error {

	int gitError = git_reference_rename(self.ref, [NSString utf8StringForString:newName]);
	if(gitError != GIT_SUCCESS) {
		if(error != NULL)
			*error = [NSError gitErrorForRenameRef:gitError];
	}
}

- (NSString *)type {
	
	return [NSString stringForUTF8String:git_object_type2string(git_reference_type(self.ref))];
}

- (NSString *)target {
	
	if(git_reference_type(self.ref) == GIT_REF_OID) {
		
		return [GTLib hexFromOid:git_reference_oid(self.ref)];
	}
	else {
		return [NSString stringForUTF8String:git_reference_target(self.ref)];
	}
}
- (void)setTarget:(NSString *)newTarget error:(NSError **)error {
	
	int gitError;
	
	if(git_reference_type(self.ref) == GIT_REF_OID) {
		
		git_oid oid;
		gitError = git_oid_mkstr(&oid, [NSString utf8StringForString:newTarget]);
		if(gitError != GIT_SUCCESS){
			if(error != NULL)
				*error = [NSError gitErrorForMkStr:gitError];
			return;
		}
		
		gitError = git_reference_set_oid(self.ref, &oid);
	}
	else {
		
		gitError = git_reference_set_target(self.ref, [NSString utf8StringForString:newTarget]);
	}

	if(gitError != GIT_SUCCESS){
		if(error != NULL)
			*error = [NSError gitErrorForSetRefTarget:gitError];
		return;
	}
}

- (void)packAllAndReturnError:(NSError **)error {
	
	int gitError = git_reference_packall(self.repo.repo);
	if(gitError != GIT_SUCCESS){
		if(error != NULL)
			*error = [NSError gitErrorForPackAllRefs:gitError];
		return;
	}
}

- (void)deleteAndReturnError:(NSError **)error {
	
	int gitError = git_reference_delete(self.ref);
	if(gitError != GIT_SUCCESS){
		if(error != NULL)
			*error = [NSError gitErrorForDeleteRef:gitError];
		return;
	}
	self.ref = NULL; /* this has been free'd */
}

- (GTReference *)resolveAndReturnError:(NSError **)error {
	
	return [GTReference referenceByResolvingRef:self error:error];
}

- (const git_oid *)oid {
	return git_reference_oid(self.ref);
}

- (void)dealloc {
	
	self.repo = nil;
	// All these properties pass through to underlying C object
	// there is nothing to release here
	//self.name = nil;
	//self.type = nil;
	[super dealloc];
}

@end
