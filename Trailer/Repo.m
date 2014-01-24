
#import "Repo.h"

@implementation Repo

@dynamic fullName;
@dynamic active;
@dynamic fork;

+(Repo*)repoWithInfo:(NSDictionary*)info moc:(NSManagedObjectContext*)moc
{
	Repo *r = [DataItem itemWithInfo:info type:@"Repo" moc:moc];
	r.fullName = [info ofk:@"full_name"];
	r.fork = @([[info ofk:@"fork"] boolValue]);
	return r;
}

+(NSArray *)activeReposInMoc:(NSManagedObjectContext *)moc
{
	NSFetchRequest *f = [NSFetchRequest fetchRequestWithEntityName:@"Repo"];
	f.predicate = [NSPredicate predicateWithFormat:@"active = YES"];
	return [moc executeFetchRequest:f error:nil];
}

-(void)prepareForDeletion
{
	for(PullRequest *r in [PullRequest allItemsOfType:@"PullRequest" inMoc:self.managedObjectContext])
	{
		if([r.repoId isEqualToNumber:self.serverId])
		{
			[self.managedObjectContext deleteObject:r];
		}
	}
}

@end